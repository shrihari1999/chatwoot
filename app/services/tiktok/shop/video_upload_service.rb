# Uploads a video to TikTok Shop and returns the resource_id (`vid`) to send in a
# VIDEO message. Implements the 3-step Large File Upload flow:
#   1. init  -> upload_url + upload_token
#   2. PUT each 5-30 MB chunk; the final chunk's response carries `resource_id`
#   3. caller sends the resource_id as the `vid` in send_message(type: VIDEO)
#
# Returns the resource_id String, or nil on any failure (caller surfaces a
# failed-message status). Customer Service videos are capped at 100 MB.
class Tiktok::Shop::VideoUploadService
  pattr_initialize [:channel!, :conversation_id!, :bytes!, :filename!, :content_type]

  CHUNK_SIZE = 20 * 1024 * 1024 # 20 MB (a single chunk must be 5-30 MB)
  MIN_CHUNK  = 5 * 1024 * 1024
  SUPPORTED_CONTENT_TYPES = %w[video/mp4 video/quicktime video/webm].freeze

  def perform
    chunks = build_chunks
    init = client.init_file_upload(
      file_name: filename, file_size: bytes.bytesize,
      total_chunk_count: chunks.size, target_path: target_path
    )
    return log_failure('init', init) unless init.success?

    upload_url = init.body.dig('data', 'upload_url')
    upload_token = init.body.dig('data', 'upload_token')
    return log_failure('init-missing-url', init) if upload_url.blank? || upload_token.blank?

    upload_chunks(upload_url, upload_token, chunks)
  end

  private

  def upload_chunks(upload_url, upload_token, chunks)
    resource_id = nil
    chunks.each_with_index do |chunk, idx|
      resp = client.upload_file_chunk(
        upload_url: upload_url, upload_token: upload_token,
        chunk_num: idx + 1, content_type: resolved_content_type, bytes: chunk
      )
      return log_failure("chunk-#{idx + 1}/#{chunks.size}", resp) unless resp.success?

      rid = extract_resource_id(resp)
      resource_id = rid if rid.present?
    end
    Rails.logger.info("[TikTok Shop] video upload complete resource_id=#{resource_id.inspect}")
    resource_id
  end

  def extract_resource_id(resp)
    resp.body['resource_id'] || resp.body.dig('data', 'resource_id')
  end

  def build_chunks
    return [bytes] if bytes.bytesize <= CHUNK_SIZE

    chunks = []
    offset = 0
    while offset < bytes.bytesize
      chunks << bytes.byteslice(offset, CHUNK_SIZE)
      offset += CHUNK_SIZE
    end
    # The final chunk must be >= 5 MB; fold a too-small tail into the previous one.
    if chunks.size > 1 && chunks.last.bytesize < MIN_CHUNK
      tail = chunks.pop
      chunks[-1] += tail
    end
    chunks
  end

  def resolved_content_type
    SUPPORTED_CONTENT_TYPES.include?(content_type) ? content_type : 'video/mp4'
  end

  # The file-init permission/routing check binds the upload to the Send Message
  # endpoint where the resulting vid will be used.
  def target_path
    "[POST]/customer_service/202606/conversations/#{conversation_id}/messages"
  end

  def client
    @client ||= Tiktok::Shop::Client.new(channel: channel)
  end

  def log_failure(step, response)
    Rails.logger.error("[TikTok Shop] video upload failed at #{step}: code=#{response.code} message=#{response.message}")
    nil
  end
end
