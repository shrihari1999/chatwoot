require 'active_support/number_helper'

# Applies Attachments::ImageCompressor to canned response images already in storage.
# New uploads are compressed at the door by Api::V1::Accounts::UploadController; this
# covers everything stored before that existed.
#
# Originals are never deleted. Compression is lossy — opaque PNGs come back as JPEGs —
# so replaced blob ids are logged for a deliberate follow-up purge.
class CannedResponses::ImageBackfill
  ORPHANED_BLOBS_LOG = 'log/compressed_canned_response_originals.log'.freeze

  def initialize(account_id: nil, mode: 'dry')
    @account_id = account_id.presence
    @commit = mode.to_s == 'commit'
    @stats = { seen: 0, compressed: 0, skipped: 0, failed: 0, before: 0, after: 0 }
  end

  def run
    print_header
    attachments.find_each { |attachment| process(attachment) }
    print_summary
    @stats
  end

  private

  def attachments
    scope = ActiveStorage::Attachment.where(record_type: 'CannedResponse').includes(:blob)
    return scope if @account_id.blank?

    scope.where(record_id: CannedResponse.where(account_id: @account_id).select(:id))
  end

  def process(attachment)
    blob = attachment.blob
    @stats[:seen] += 1
    @stats[:before] += blob.byte_size

    result = compress(blob)
    return record_skip(blob) if result.nil?

    report_saving(blob, result)
    @stats[:compressed] += 1
    @stats[:after] += result[:io].size

    replace_blob!(attachment, result) if @commit
  rescue StandardError => e
    @stats[:failed] += 1
    log "  !! blob #{attachment.blob_id}: #{e.message}"
  end

  def compress(blob)
    blob.open do |file|
      Attachments::ImageCompressor.new(
        io: file, filename: blob.filename.to_s, content_type: blob.content_type
      ).compress
    end
  end

  def record_skip(blob)
    @stats[:skipped] += 1
    @stats[:after] += blob.byte_size
    nil
  end

  # A new blob rather than a rewrite: changing an existing blob's bytes would leave its
  # checksum, byte_size and any generated variants stale.
  def replace_blob!(attachment, result)
    old_blob_id = attachment.blob.id

    new_blob = ActiveStorage::Blob.create_and_upload!(
      io: result[:io], filename: result[:filename], content_type: result[:content_type]
    )
    attachment.update!(blob: new_blob)

    File.open(Rails.root.join(ORPHANED_BLOBS_LOG), 'a') { |f| f.puts(old_blob_id) }
  end

  def report_saving(blob, result)
    saved = 100.0 * (blob.byte_size - result[:io].size) / blob.byte_size
    log format('  %<name>-42s %<from>9s -> %<to>9s  (-%<pct>.1f%%)  %<type>-10s %<mode>s',
               name: blob.filename.to_s[0, 42], from: size(blob.byte_size),
               to: size(result[:io].size), pct: saved, type: result[:content_type],
               mode: result[:lossless] ? 'LOSSLESS' : 'lossy')
  end

  def size(bytes)
    ActiveSupport::NumberHelper.number_to_human_size(bytes)
  end

  def print_header
    log @commit ? 'Mode: COMMIT (blobs will be replaced)' : 'Mode: DRY RUN (nothing is written)'
    log "Scope: #{@account_id ? "account #{@account_id}" : 'all accounts'}"
    log "Threshold: #{Attachments::ImageCompressor::MAX_BYTES / 1.megabyte} MB\n\n"
  end

  def print_summary
    log "\n#{'-' * 60}"
    %i[seen compressed skipped failed].each { |key| log format('%<k>-16s %<v>s', k: "#{key}:", v: @stats[key]) }
    log format('%<k>-16s %<v>s', k: 'total before:', v: size(@stats[:before]))
    log format('%<k>-16s %<v>s', k: 'total after:', v: size(@stats[:after]))
    log format('%<k>-16s %<v>s', k: 'saved:', v: size(@stats[:before] - @stats[:after]))
    log @commit ? commit_footer : "\n(DRY RUN — re-run with mode=commit to apply.)"
  end

  def commit_footer
    "\nOriginals were NOT deleted. Replaced blob ids are in #{ORPHANED_BLOBS_LOG}; " \
      'review the compressed images, then purge those blobs deliberately.'
  end

  # This is a rake-invoked reporter; stdout is the point.
  def log(message)
    puts message # rubocop:disable Rails/Output
  end
end
