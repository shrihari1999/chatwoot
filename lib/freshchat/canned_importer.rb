# frozen_string_literal: true

require 'open-uri'

# Imports Freshchat canned responses (exported to markdown by the shopify_django_app
# `freshchat_canned_response` command) into Chatwoot.
#
# Export format:
#   ## Category name
#   ### Response title          <- becomes short_code (verbatim, trimmed)
#   body text...                <- becomes content (image-URL lines removed)
#   https://fc-aps1-...png      <- Freshchat image -> downloaded & attached as a file
#
# Freshchat is treated as the source of truth: `commit` mode WIPES every canned
# response + category (and their image blobs) for the account, then rebuilds from
# the file. `dry` mode writes nothing and prints a current-vs-planned comparison.
module Freshchat
  class CannedImporter
    # Freshchat hosts canned-response images on this S3 bucket. A standalone URL line
    # is treated as an image only if it's on this host or ends in an image extension —
    # this keeps genuine content links (Fuze tracking, g.co maps, Instagram, Lazada,
    # LINE, TikTok) inside the response body instead of mistaking them for images.
    IMAGE_HOST = 'fc-aps1-00-pics-bkt-00.s3.ap-south-1.amazonaws.com'
    IMAGE_EXT_RE = /\.(png|jpe?g|gif|webp)(\?.*)?\z/i
    BARE_URL_RE = %r{\Ahttps?://\S+\z}

    BEFORE_SNAPSHOT = '/tmp/canned_BEFORE.tsv'
    AFTER_SNAPSHOT  = '/tmp/canned_AFTER.tsv'

    def initialize(account_id:, file_path:, mode: 'dry')
      @account = Account.find(account_id)
      @file_path = file_path
      @mode = mode.to_s.strip.downcase
      raise ArgumentError, "mode must be 'dry' or 'commit' (got #{@mode.inspect})" unless %w[dry commit].include?(@mode)
      raise ArgumentError, "file not found: #{@file_path}" unless File.exist?(@file_path)
    end

    def run
      categories = parse(File.read(@file_path, encoding: 'UTF-8'))
      log "Parsed #{categories.size} categories, #{categories.sum { |c| c[:entries].size }} entries from #{@file_path}"
      @mode == 'commit' ? commit(categories) : dry_run(categories)
    end

    private

    # ── Parsing ──────────────────────────────────────────────

    # Returns [{ name:, entries: [{ short_code:, content:, images: [url, ...] }, ...] }, ...]
    def parse(text)
      categories = []
      current_cat = nil
      current_entry = nil
      body = nil

      flush = lambda do
        next unless current_entry

        current_entry[:content], current_entry[:images] = split_body(body)
        current_cat[:entries] << current_entry
        current_entry = nil
        body = nil
      end

      text.each_line do |raw|
        line = raw.chomp
        if line.start_with?('### ')
          flush.call
          current_entry = { short_code: line.sub(/\A###\s+/, '').strip }
          body = []
        elsif line.start_with?('## ')
          flush.call
          current_cat = { name: line.sub(/\A##\s+/, '').strip, entries: [] }
          categories << current_cat
        elsif current_entry
          body << line
        end
      end
      flush.call

      categories
    end

    def split_body(lines)
      images = []
      text_lines = []
      (lines || []).each do |line|
        s = line.strip
        next if s.empty?

        if image_url?(s)
          images << s
        else
          text_lines << s
        end
      end
      [text_lines.join("\n\n"), images]
    end

    def image_url?(str)
      return false unless str.match?(BARE_URL_RE)

      host = begin
        URI.parse(str).host
      rescue URI::InvalidURIError
        nil
      end
      return true if host == IMAGE_HOST

      str.match?(IMAGE_EXT_RE)
    end

    # Flatten to ordered response rows, dropping duplicate short_codes within a
    # category (the [account, category, short_code] unique index forbids them).
    # Returns [rows, skipped_dupes].
    def flatten(categories)
      rows = []
      skipped = []
      seen = {}
      categories.each do |cat|
        cat[:entries].each do |e|
          sc = e[:short_code]
          next if sc.blank?

          key = [cat[:name], sc]
          if seen[key]
            skipped << "#{cat[:name]} / #{sc}"
            next
          end
          seen[key] = true
          rows << e.merge(category: cat[:name])
        end
      end
      [rows, skipped]
    end

    # ── Dry run ──────────────────────────────────────────────

    def dry_run(categories)
      rows, skipped = flatten(categories)
      write_before_snapshot
      write_after_snapshot(rows)

      current_by_cat = @account.canned_responses.includes(:category).group_by { |r| r.category&.name }
      planned_by_cat = rows.group_by { |r| r[:category] }
      current_cats = current_by_cat.keys.compact
      planned_cats = categories.map { |c| c[:name] }

      log "\n================ DRY RUN — no changes written ================"
      log "Account: #{@account.id} (#{@account.name})"
      log "\n-- Totals --"
      log "  current: #{@account.canned_response_categories.count} categories, " \
          "#{@account.canned_responses.count} responses, " \
          "#{@account.canned_responses.select { |r| r.files.attached? }.size} with attachments"
      log "  planned: #{planned_cats.size} categories, #{rows.size} responses, " \
          "#{rows.sum { |r| r[:images].size }} images to download"

      log "\n-- Categories only in CURRENT (will be DELETED) --"
      (current_cats - planned_cats).sort.each { |c| log "  - #{c} (#{current_by_cat[c].size})" }
      log "\n-- Categories only in PLANNED (will be CREATED) --"
      (planned_cats - current_cats).sort.each { |c| log "  + #{c} (#{planned_by_cat[c]&.size || 0})" }

      log "\n-- Response counts per category (current -> planned) --"
      (current_cats | planned_cats).sort.each do |c|
        log format('  %-45s %3d -> %3d', c.to_s[0, 45], current_by_cat[c]&.size || 0, planned_by_cat[c]&.size || 0)
      end

      if skipped.any?
        log "\n-- ⚠ Duplicate short_codes within a category (rest will be SKIPPED) --"
        skipped.each { |s| log "  ! #{s}" }
      end

      empties = rows.select { |r| r[:content].blank? && r[:images].empty? }
      if empties.any?
        log "\n-- ⚠ Entries with NO content and NO image (cannot be saved, will be SKIPPED) --"
        empties.each { |r| log "  ! #{r[:category]} / #{r[:short_code]}" }
      end

      check_image_sample(rows)

      log "\nSnapshots written:\n  before: #{BEFORE_SNAPSHOT}\n  after:  #{AFTER_SNAPSHOT}"
      log "Compare with:  diff <(sort #{BEFORE_SNAPSHOT}) <(sort #{AFTER_SNAPSHOT})"
      log "=============================================================="
    end

    def write_before_snapshot
      rows = @account.canned_responses.includes(:category).map do |r|
        [r.category&.name, r.short_code, r.content.to_s.length, r.files.count]
      end
      write_tsv(BEFORE_SNAPSHOT, %w[category short_code content_len attachments], rows)
    end

    def write_after_snapshot(rows)
      data = rows.map { |r| [r[:category], r[:short_code], r[:content].to_s.length, r[:images].size] }
      write_tsv(AFTER_SNAPSHOT, %w[category short_code content_len images], data)
    end

    def write_tsv(path, header, rows)
      File.open(path, 'w') do |f|
        f.puts header.join("\t")
        rows.sort_by { |r| [r[0].to_s, r[1].to_s] }.each { |r| f.puts r.join("\t") }
      end
    end

    def check_image_sample(rows)
      urls = rows.flat_map { |r| r[:images] }.uniq.first(3)
      return if urls.empty?

      log "\n-- Image reachability sample --"
      urls.each do |url|
        io = URI.parse(url).open(read_timeout: 15)
        log "  ok   (#{io.content_type}, #{io.size} bytes) #{url[0, 80]}"
        io.close
      rescue StandardError => e
        log "  FAIL #{e.class}: #{url[0, 80]}"
      end
    end

    # ── Commit ───────────────────────────────────────────────

    def commit(categories)
      rows, skipped = flatten(categories)
      log "\n================ COMMIT — wiping & rebuilding ================"
      log "Skipping #{skipped.size} duplicate short_codes" if skipped.any?

      wipe!

      cat_map = {}
      categories.each do |c|
        next if c[:entries].empty?

        cat_map[c[:name]] = @account.canned_response_categories.create!(name: c[:name], visibility: :everyone)
      end
      log "Created #{cat_map.size} categories"

      created = 0
      errors = []
      rows.each do |row|
        if row[:content].blank? && row[:images].empty?
          errors << "#{row[:category]} / #{row[:short_code]}: no content and no image — skipped"
          next
        end

        begin
          cr = @account.canned_responses.new(
            short_code: row[:short_code],
            content: row[:content],
            category: cat_map[row[:category]]
          )
          attach_images(cr, row[:images], errors)
          cr.save!
          created += 1
          log "  created #{created}/#{rows.size}" if (created % 25).zero?
        rescue StandardError => e
          errors << "#{row[:category]} / #{row[:short_code]}: #{e.message}"
        end
      end

      log "\nDone. Created #{created} responses across #{cat_map.size} categories."
      if errors.any?
        log "\n-- #{errors.size} errors/skips --"
        errors.each { |e| log "  ! #{e}" }
      end
      log "============================================================="
    end

    def wipe!
      # Use class-scoped relation deletes (direct SQL DELETE). Association-proxy
      # `delete_all` would NULLIFY canned_responses.account_id (Rails default),
      # which violates the NOT NULL constraint. Delete responses before categories
      # to satisfy the on_delete: :restrict foreign key.
      CannedResponse.where(account_id: @account.id).find_each { |r| r.files.purge }
      count_r = CannedResponse.where(account_id: @account.id).delete_all
      count_c = CannedResponseCategory.where(account_id: @account.id).delete_all
      log "Wiped #{count_r} responses (purged attachments) and #{count_c} categories"
    end

    def attach_images(canned_response, urls, errors)
      urls.each do |url|
        io = URI.parse(url).open(read_timeout: 30)
        canned_response.files.attach(
          io: io,
          filename: File.basename(URI.parse(url).path),
          content_type: io.respond_to?(:content_type) ? io.content_type : nil
        )
      rescue StandardError => e
        errors << "#{canned_response.short_code}: image download failed (#{e.message}) #{url[0, 80]}"
      end
    end

    def log(msg)
      puts msg
    end
  end
end
