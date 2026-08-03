require 'active_support/number_helper'

# Warms the preview variants that CannedResponse#file_base_data links to.
#
# Active Storage builds a variant lazily, inside whichever request first asks for it.
# Without this, the first agent to open the canned-response picker after a deploy pays
# for every missing variant synchronously. Run it once after deploying.
class CannedResponses::ThumbnailGenerator
  DIMENSION = CannedResponse::THUMB_DIMENSION

  def initialize(account_id: nil)
    @account_id = account_id.presence
    @stats = { seen: 0, generated: 0, skipped: 0, failed: 0 }
  end

  def run
    log "Warming #{DIMENSION}px canned response thumbnails" \
        "#{@account_id ? " for account #{@account_id}" : ''}\n"
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
    @stats[:seen] += 1
    blob = attachment.blob

    return @stats[:skipped] += 1 unless blob.representable?

    blob.representation(resize_to_limit: [DIMENSION, DIMENSION]).processed
    @stats[:generated] += 1
  rescue StandardError => e
    @stats[:failed] += 1
    log "  !! blob #{attachment.blob_id}: #{e.message}"
  end

  def print_summary
    %i[seen generated skipped failed].each { |key| log format('%<k>-14s %<v>s', k: "#{key}:", v: @stats[key]) }
  end

  # Rake-invoked reporter; stdout is the point.
  def log(message)
    puts message # rubocop:disable Rails/Output
  end
end
