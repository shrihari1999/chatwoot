# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
class Freshchat::Importer # rubocop:disable Metrics/ClassLength
  BATCH_SIZE = 200

  CHANNEL_PLATFORM = {
    'LINE - TRP' => 'Channel::Line',
    'LINE' => 'Channel::Line',
    'LINE - Chocogems' => 'Channel::Line',
    'IG_therollingpinn' => 'Channel::Instagram',
    'IG_chocogems.th' => 'Channel::Instagram',
    'The Rolling Pinn' => 'Channel::FacebookPage',
    'TikTok Shop' => 'Channel::TiktokShop',
    'TikTok' => 'Channel::TiktokShop',
    'Lazada IM' => 'Channel::Lazada'
  }.freeze

  IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .gif .webp .heic].freeze
  VIDEO_EXTENSIONS = %w[.mp4 .mov .webm .m4v .3gp].freeze

  SOURCE_CONV_COLUMNS = %i[id conversation_id customer_id].freeze
  SOURCE_MSG_COLUMNS  = %i[
    id message_id conversation_id created_time
    actor_type actor_id actor_first_name detailed_message_type message_source
    message image_url video_url
  ].freeze

  INSERT_SLICE = 2_000

  attr_reader :inbox, :channels, :dry_run, :limit, :since, :stats

  # since:  nil       -> auto (read marker file, fall back to full scan)
  #         :full     -> ignore marker file, full scan
  #         Time/iso  -> explicit lower bound on source `created_time`
  def initialize(inbox:, channels:, dry_run: false, limit: nil, since: nil)
    @inbox = inbox
    @channels = Array(channels).map(&:to_s)
    @dry_run = dry_run
    @limit = limit
    @since = since
    @stats = Hash.new(0)
  end

  def run
    validate!
    Freshchat::SourceBase.connect!

    effective_since = resolve_since
    # Capture the run-start wall-clock BEFORE any source reading. The next
    # delta-sync uses this as its lower bound, so we never miss a source row
    # that landed AFTER we'd already processed its conversation in this run.
    # Trade-off: next run re-scans messages from this window (idempotency
    # dedupes them) — bounded overhead, but always-correct.
    run_started_at = Time.current

    log "Starting #{dry_run ? 'DRY-RUN ' : ''}import: inbox=#{inbox.id} (#{inbox.channel_type}) " \
        "channels=#{channels.inspect} limit=#{limit || '∞'} since=#{effective_since&.iso8601 || 'FULL'}"

    ActiveRecord::Base.transaction do
      scope = scope_for(effective_since)
      scope.find_in_batches(batch_size: BATCH_SIZE) do |source_convs|
        process_batch(source_convs, effective_since)
      end

      if dry_run
        log 'DRY-RUN: rolling back all changes'
        raise ActiveRecord::Rollback
      end
    end

    save_sync_state!(run_started_at) unless dry_run
    print_stats
    stats
  end

  private

  def validate!
    raise ArgumentError, 'channels cannot be empty' if channels.empty?

    mapped = channels.map { |c| CHANNEL_PLATFORM[c] || (raise ArgumentError, "Unknown Freshchat channel: #{c.inspect}") }.uniq
    raise ArgumentError, "Channels span multiple platforms: #{mapped.inspect}" if mapped.size > 1

    expected = mapped.first
    return if inbox.channel_type == expected

    raise ArgumentError, "Inbox #{inbox.id} has channel_type=#{inbox.channel_type}, but channels #{channels.inspect} require #{expected}"
  end

  # nil-since means full scan; a Time means "only conversations that have at
  # least one source message with created_time >= since (within our channels)".
  def scope_for(effective_since)
    scope = Freshchat::SourceConversation.select(SOURCE_CONV_COLUMNS).where(channel_name: channels).order(:id)
    if effective_since
      delta_conv_ids = Freshchat::SourceMessage
                       .where('created_time >= ?', effective_since)
                       .where(conversation_id: Freshchat::SourceConversation.where(channel_name: channels).select(:id))
                       .distinct
                       .pluck(:conversation_id)
      scope = scope.where(id: delta_conv_ids)
    end
    scope = scope.limit(limit) if limit
    scope
  end

  def process_batch(source_convs, effective_since)
    stats[:source_conversations_seen] += source_convs.size

    msgs_by_conv = load_messages_for_batch(source_convs.map(&:id), effective_since)
    customer_info = derive_customer_info(source_convs, msgs_by_conv)

    contact_id_by_customer = upsert_contacts(customer_info)
    upsert_contact_inboxes(source_convs, contact_id_by_customer, customer_info)
    ci_id_by_contact = load_contact_inbox_ids(contact_id_by_customer.values)
    conv_lookup = upsert_conversations(source_convs, msgs_by_conv, contact_id_by_customer, ci_id_by_contact)
    upsert_messages_and_attachments(source_convs, msgs_by_conv, conv_lookup, contact_id_by_customer)

    log_batch_progress(source_convs.size)
  end

  # Returns { customer_id => { name:, actor_id: } } by scanning messages.
  # Picks the first user-type message per customer (falls back to first message
  # of any type if no user-type message exists).
  def derive_customer_info(source_convs, msgs_by_conv)
    info = {}
    source_convs.each do |conv|
      next if conv.customer_id.nil? || info.key?(conv.customer_id)

      msgs = msgs_by_conv[conv.id] || []
      ref = msgs.find { |m| m.actor_type.to_s.casecmp('user').zero? } || msgs.first
      info[conv.customer_id] = {
        name: ref&.actor_first_name.to_s,
        actor_id: ref&.actor_id
      }
    end
    info
  end

  def load_messages_for_batch(conv_ids, effective_since)
    rel = Freshchat::SourceMessage.select(SOURCE_MSG_COLUMNS)
                                  .where(conversation_id: conv_ids)
                                  .order(:conversation_id, :created_time)
    rel = rel.where('created_time >= ?', effective_since) if effective_since
    all_msgs = rel.to_a

    # Drop a row if EITHER signal says "not a real chat message":
    #   - message_source='system' catches Freshchat workflow events
    #     ("Conversation was marked resolved by <agent>"), where actor_type
    #     can be agent/user depending on who triggered it.
    #   - actor_type='system' catches IG-side social events (COMMENT on a
    #     post, STORY_MENTION, STORY_REPLY, SHARE) on LINE/IG channels,
    #     where message_source is empty string.
    system_msgs, kept = all_msgs.partition do |m|
      m.message_source.to_s.casecmp('system').zero? || m.actor_type.to_s.casecmp('system').zero?
    end
    stats[:system_messages_skipped] += system_msgs.size
    kept.group_by(&:conversation_id)
  end

  def upsert_contacts(customer_info)
    customer_ids = customer_info.keys
    return {} if customer_ids.empty?

    existing = pluck_lookup(Contact, 'freshchat_customer_id', customer_ids)
    missing_ids = customer_ids - existing.keys
    return existing if missing_ids.empty?

    now = Time.current
    rows = missing_ids.map do |cid|
      info = customer_info[cid]
      {
        account_id: inbox.account_id,
        name: info[:name].presence || '',
        additional_attributes: { 'freshchat_customer_id' => cid, 'freshchat_actor_id' => info[:actor_id] }.compact,
        created_at: now,
        updated_at: now
      }
    end

    result = Contact.insert_all(rows, returning: Arel.sql("id, additional_attributes->>'freshchat_customer_id' AS fc_customer_id")) # rubocop:disable Rails/SkipsModelValidations
    result.each { |row| existing[row['fc_customer_id']] = row['id'] }
    stats[:contacts_created] += result.length

    existing
  end

  def upsert_contact_inboxes(source_convs, contact_id_by_customer, customer_info)
    rows = source_convs.filter_map { |c| build_contact_inbox_row(c, contact_id_by_customer, customer_info) }
                       .uniq { |r| [r[:inbox_id], r[:source_id]] }
    return if rows.empty?

    result = ContactInbox.insert_all(rows, unique_by: %i[inbox_id source_id]) # rubocop:disable Rails/SkipsModelValidations
    stats[:contact_inboxes_created] += result.length
  end

  def build_contact_inbox_row(source_conv, contact_id_by_customer, customer_info)
    contact_id = contact_id_by_customer[source_conv.customer_id]
    return nil if contact_id.nil?

    {
      contact_id: contact_id,
      inbox_id: inbox.id,
      source_id: contact_inbox_source_id(source_conv, customer_info),
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  def contact_inbox_source_id(source_conv, customer_info)
    info = customer_info[source_conv.customer_id]
    info&.dig(:actor_id).presence || "freshchat-customer-#{source_conv.customer_id}"
  end

  def load_contact_inbox_ids(contact_ids)
    return {} if contact_ids.empty?

    ContactInbox.where(inbox_id: inbox.id, contact_id: contact_ids).pluck(:contact_id, :id).to_h
  end

  def upsert_conversations(source_convs, msgs_by_conv, contact_id_by_customer, ci_id_by_contact)
    fc_conv_ids = source_convs.map(&:conversation_id)
    existing = pluck_lookup(Conversation, 'freshchat_conversation_id', fc_conv_ids)
    missing = source_convs.reject { |c| existing.key?(c.conversation_id) }
    return existing if missing.empty?

    rows = missing.filter_map { |c| build_conversation_row(c, msgs_by_conv, contact_id_by_customer, ci_id_by_contact) }
    return existing if rows.empty?

    result = Conversation.insert_all(rows, returning: Arel.sql("id, additional_attributes->>'freshchat_conversation_id' AS fc_conv_id")) # rubocop:disable Rails/SkipsModelValidations
    result.each { |row| existing[row['fc_conv_id']] = row['id'] }
    stats[:conversations_created] += result.length

    existing
  end

  def build_conversation_row(source_conv, msgs_by_conv, contact_id_by_customer, ci_id_by_contact)
    contact_id = contact_id_by_customer[source_conv.customer_id]
    ci_id = ci_id_by_contact[contact_id]
    return nil if contact_id.nil? || ci_id.nil?

    msgs = msgs_by_conv[source_conv.id] || []
    first_time = msgs.first&.created_time || Time.current
    last_time = msgs.last&.created_time || first_time

    {
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: contact_id,
      contact_inbox_id: ci_id,
      status: 1,
      created_at: first_time,
      updated_at: last_time,
      last_activity_at: last_time,
      additional_attributes: {
        'freshchat_conversation_id' => source_conv.conversation_id
      }
    }
  end

  def upsert_messages_and_attachments(source_convs, msgs_by_conv, conv_lookup, contact_id_by_customer)
    all_msgs = msgs_by_conv.values.flatten
    return if all_msgs.empty?

    existing_msg_ids = pluck_lookup(Message, 'freshchat_message_id', all_msgs.map(&:message_id)).keys.to_set
    conv_by_id = source_convs.index_by(&:id)

    msg_rows, attachment_pending = build_message_rows(msgs_by_conv, conv_by_id, conv_lookup, contact_id_by_customer, existing_msg_ids)
    return if msg_rows.empty?

    msg_id_by_fc = {}
    msg_rows.each_slice(INSERT_SLICE) do |slice|
      result = Message.insert_all(slice, returning: Arel.sql("id, additional_attributes->>'freshchat_message_id' AS fc_id")) # rubocop:disable Rails/SkipsModelValidations
      result.each { |row| msg_id_by_fc[row['fc_id']] = row['id'] }
      stats[:messages_created] += slice.length
    end

    insert_attachments(attachment_pending, msg_id_by_fc) if attachment_pending.any?
  end

  def build_message_rows(msgs_by_conv, conv_by_id, conv_lookup, contact_id_by_customer, existing_msg_ids)
    msg_rows = []
    attachments = []

    msgs_by_conv.each do |fc_conv_pk, fc_msgs|
      fc_conv = conv_by_id[fc_conv_pk]
      next if fc_conv.nil?

      chatwoot_conv_id = conv_lookup[fc_conv.conversation_id]
      contact_id = contact_id_by_customer[fc_conv.customer_id]
      next if chatwoot_conv_id.nil? || contact_id.nil?

      fc_msgs.each do |m|
        next if existing_msg_ids.include?(m.message_id)

        row = build_message_row(m, chatwoot_conv_id, contact_id)
        next if row.nil?

        msg_rows << row
        attachments << build_pending_attachment(m, m.image_url, :image) if m.image_url.present?
        attachments << build_pending_attachment(m, m.video_url, :video) if m.video_url.present?
      end
    end

    [msg_rows, attachments]
  end

  def build_message_row(msg, chatwoot_conv_id, contact_id)
    message_type = source_message_type(msg)
    return nil if message_type.nil?

    incoming = message_type.zero?
    text = msg.message.to_s
    {
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      conversation_id: chatwoot_conv_id,
      message_type: message_type,
      content: text,
      processed_message_content: text,
      content_type: 0,
      status: imported_message_status,
      source_id: msg.message_id,
      private: false,
      content_attributes: {},
      sender_type: incoming ? 'Contact' : nil,
      sender_id: incoming ? contact_id : nil,
      additional_attributes: {
        'freshchat_message_id' => msg.message_id,
        'freshchat_actor_type' => msg.actor_type,
        'freshchat_detailed_type' => msg.detailed_message_type
      },
      created_at: msg.created_time,
      updated_at: msg.created_time
    }
  end

  # Pick the status that makes the UI render a meaningful delivery indicator
  # instead of the in-flight clock (MESSAGE_STATUS.PROGRESS fallback in
  # dashboard/components-next/message/MessageMeta.vue). LINE has no isRead
  # branch but uses status===DELIVERED in isDelivered; Lazada/IG/FB/TikTok
  # use status===READ + source_id in isRead. Setting source_id (which we do
  # unconditionally above) makes the non-LINE branches work; status picks
  # the right tier for each channel.
  def imported_message_status
    inbox.channel_type == 'Channel::Line' ? 1 : 2
  end

  def build_pending_attachment(msg, url, hint)
    {
      fc_message_id: msg.message_id,
      external_url: url,
      file_type: attachment_file_type(url, hint),
      account_id: inbox.account_id
    }
  end

  def source_message_type(msg)
    case msg.actor_type.to_s.downcase
    when 'user' then 0
    when 'agent' then 1
    end
  end

  def attachment_file_type(url, hint)
    path = URI.parse(url.to_s).path.to_s.downcase
    ext = File.extname(path)
    return Attachment.file_types[:image] if IMAGE_EXTENSIONS.include?(ext)
    return Attachment.file_types[:video] if VIDEO_EXTENSIONS.include?(ext)

    # Fall back to the source-column hint (image_url vs video_url) when the
    # extension is ambiguous (e.g. Freshchat CDN URLs with no extension).
    Attachment.file_types[hint] || Attachment.file_types[:file]
  rescue URI::InvalidURIError
    Attachment.file_types[hint] || Attachment.file_types[:file]
  end

  def insert_attachments(pending, msg_id_by_fc)
    now = Time.current
    rows = pending.filter_map do |p|
      msg_id = msg_id_by_fc[p[:fc_message_id]]
      next if msg_id.nil?

      { message_id: msg_id, account_id: p[:account_id], external_url: p[:external_url], file_type: p[:file_type], created_at: now, updated_at: now }
    end

    rows.each_slice(INSERT_SLICE) do |slice|
      Attachment.insert_all(slice) # rubocop:disable Rails/SkipsModelValidations
      stats[:attachments_created] += slice.length
    end
  end

  def pluck_lookup(model, json_key, ids)
    return {} if ids.empty?

    # json_key is always a hardcoded constant from this file — safe to interpolate.
    expr = "additional_attributes->>'#{json_key}'"
    model.where(account_id: inbox.account_id)
         .where("#{expr} IN (?)", ids)
         .pluck(Arel.sql(expr), :id)
         .to_h
  end

  def log_batch_progress(batch_size)
    log "Batch processed (#{batch_size} convs): " \
        "contacts=+#{stats[:contacts_created] - @prev_contacts.to_i} " \
        "convs=+#{stats[:conversations_created] - @prev_convs.to_i} " \
        "msgs=+#{stats[:messages_created] - @prev_msgs.to_i}"
    @prev_contacts = stats[:contacts_created]
    @prev_convs = stats[:conversations_created]
    @prev_msgs = stats[:messages_created]
  end

  def print_stats
    log '----- Import summary -----'
    stats.sort.each { |k, v| log "  #{k}: #{v}" }
    log '--------------------------'
  end

  def log(msg)
    Rails.logger.info("[Freshchat::Importer] #{msg}")
    Kernel.puts "[Freshchat::Importer] #{msg}"
  end

  # --- sync-state marker file ----------------------------------------------

  def sync_state_path
    Rails.root.join('log', 'freshchat', 'sync_state', "inbox-#{inbox.id}.json")
  end

  def resolve_since
    case since
    when :full then nil
    when nil
      stored = load_last_synced_at
      log "Using stored sync marker: #{stored.iso8601}" if stored
      stored
    when Time, ActiveSupport::TimeWithZone then since
    when String then Time.iso8601(since)
    else raise ArgumentError, "Unsupported since=#{since.inspect}"
    end
  end

  def load_last_synced_at
    path = sync_state_path
    return nil unless File.exist?(path)

    data = JSON.parse(File.read(path))
    ts = data['last_message_imported_at']
    ts ? Time.iso8601(ts) : nil
  rescue JSON::ParserError, ArgumentError => e
    log "WARNING: ignoring malformed sync-state file (#{e.message}); doing full scan"
    nil
  end

  # `run_started_at` is the wall-clock captured BEFORE this run started
  # reading source data. Storing it (not the max created_time we observed)
  # guarantees the next delta-sync looks back far enough to catch any source
  # rows that arrived for already-processed conversations mid-run.
  def save_sync_state!(run_started_at)
    path = sync_state_path
    FileUtils.mkdir_p(path.dirname)
    payload = {
      'inbox_id' => inbox.id,
      'channels' => channels,
      'last_message_imported_at' => run_started_at.iso8601,
      'last_run_at' => Time.current.iso8601
    }
    tmp = path.sub_ext('.tmp')
    File.write(tmp, JSON.pretty_generate(payload))
    File.rename(tmp, path)
    log "Saved sync-state -> #{path} (last_message_imported_at=#{run_started_at.iso8601})"
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
