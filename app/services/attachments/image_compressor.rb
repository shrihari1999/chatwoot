require 'image_processing/vips'

# Shrinks oversized image uploads before they are stored.
#
# Chatwoot has no compression anywhere — an over-limit upload is simply rejected in the
# browser, and anything reaching the server is stored at full resolution. Canned response
# images are the sharp edge of that: pasted phone photos land as 10 MB PNGs, get re-served
# on every send, and exceed the per-channel send limits (Facebook 8 MB, TikTok Shop 10 MB).
#
# Strategy is lossless-first. Downscaling to MAX_DIMENSION removes ~84% of the pixels of a
# 4500x5625 phone photo, which on measured production files is enough on its own to clear
# the threshold with a pixel-identical re-encode. Lossy encoding is only reached for when
# lossless genuinely cannot fit.
#
# Returns nil when nothing needs doing, so callers keep the original untouched:
#
#   result = Attachments::ImageCompressor.new(io: io, filename: f, content_type: ct).compress
#   io, filename, content_type = result.values_at(:io, :filename, :content_type) if result
#
class Attachments::ImageCompressor
  MAX_BYTES = 8.megabytes
  MAX_DIMENSION = 2560

  # Reached only when the lossless attempt is still over MAX_BYTES.
  LOSSY_ATTEMPTS = [
    { dimension: 2560, quality: 85 },
    { dimension: 2048, quality: 75 },
    { dimension: 1600, quality: 65 }
  ].freeze

  # A JPEG source cannot be re-encoded losslessly once it is resized, so its first
  # attempt is visually-lossless rather than truly lossless.
  NEAR_LOSSLESS_JPEG_QUALITY = 95

  # Alpha cannot survive a move to JPEG, so transparent images step down in size
  # instead of in quality — every attempt stays a lossless PNG.
  ALPHA_DIMENSIONS = [2560, 2048, 1600].freeze

  # image/gif is deliberately absent: vips flattens animated GIFs to a single frame
  # unless loaded with n: -1, and silently destroying an animation is worse than
  # storing a large file.
  COMPRESSIBLE_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze

  def initialize(io:, filename:, content_type:)
    @io = io
    @filename = filename.to_s
    @content_type = content_type.to_s
  end

  def compress
    return nil unless compressible? && oversized?

    best = select_best(generate_candidates)
    return nil if best.nil?

    {
      io: best[:file],
      filename: rename_to(best[:extension]),
      content_type: best[:content_type],
      lossless: best[:lossless]
    }
  rescue Vips::Error => e
    # A corrupt or unsupported image must not take the whole upload down — storing it
    # uncompressed is the correct fallback.
    Rails.logger.warn "[ImageCompressor] Skipping #{@filename}: #{e.message}"
    nil
  end

  private

  # Highest fidelity that fits; if nothing fits, the smallest we managed. Re-encoding can
  # inflate an already well-compressed file, so never return a worse result.
  def select_best(candidates)
    return nil if candidates.empty?

    best = candidates.find { |candidate| candidate[:size] <= MAX_BYTES } ||
           candidates.min_by { |candidate| candidate[:size] }

    best[:size] >= original_size ? nil : best
  end

  def compressible?
    COMPRESSIBLE_CONTENT_TYPES.include?(@content_type)
  end

  def oversized?
    original_size > MAX_BYTES
  end

  def original_size
    @original_size ||= begin
      @io.rewind
      @io.size
    end
  end

  def source_path
    @source_path ||= begin
      @io.rewind
      if @io.respond_to?(:path) && @io.path.present?
        @io.path
      else
        tempfile = Tempfile.new(['image_compressor_src', File.extname(@filename)], binmode: true)
        IO.copy_stream(@io, tempfile)
        tempfile.flush
        tempfile.path
      end
    end
  end

  def alpha?
    @alpha ||= Vips::Image.new_from_file(source_path).has_alpha?
  end

  # Ordered best-fidelity-first. Generation stops at the first candidate that fits.
  def attempts
    return ALPHA_DIMENSIONS.map { |dimension| lossless_attempt(dimension) } if alpha?

    [lossless_attempt(MAX_DIMENSION)] +
      LOSSY_ATTEMPTS.map { |attempt| attempt.merge(lossless: false) }
  end

  def lossless_attempt(dimension)
    { dimension: dimension, quality: NEAR_LOSSLESS_JPEG_QUALITY, lossless: true }
  end

  def generate_candidates
    attempts.each_with_object([]) do |attempt, candidates|
      candidate = build_candidate(attempt)
      next if candidate.nil?

      candidates << candidate
      break candidates if candidate[:size] <= MAX_BYTES
    end
  end

  def build_candidate(attempt)
    format = format_for(attempt)
    file = pipeline(attempt, format).call

    {
      file: file, size: file.size, lossless: attempt[:lossless] && format != :jpeg,
      extension: EXTENSIONS.fetch(format), content_type: CONTENT_TYPES.fetch(format)
    }
  rescue Vips::Error => e
    Rails.logger.warn "[ImageCompressor] Attempt #{attempt} failed for #{@filename}: #{e.message}"
    nil
  end

  # Lossless attempts keep the source format. Lossy fallbacks move to JPEG, which alpha
  # rules out — but alpha images only ever produce lossless attempts.
  def format_for(attempt)
    return source_format if attempt[:lossless]

    :jpeg
  end

  def source_format
    @source_format ||= { 'image/png' => :png, 'image/webp' => :webp }.fetch(@content_type, :jpeg)
  end

  EXTENSIONS = { jpeg: '.jpg', png: '.png', webp: '.webp' }.freeze
  CONTENT_TYPES = { jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp' }.freeze

  def pipeline(attempt, format)
    base = ImageProcessing::Vips
           .source(source_path)
           .resize_to_limit(attempt[:dimension], attempt[:dimension])

    case format
    when :png
      # No palette quantisation: measured on production files it was both larger and
      # measurably worse than JPEG, so it is strictly dominated.
      base.convert('png').saver(compression: 9, palette: false, strip: true)
    when :webp
      base.convert('webp').saver(**webp_saver_options(attempt))
    else
      base.convert('jpg').saver(quality: attempt[:quality], strip: true, interlace: true)
    end
  end

  def webp_saver_options(attempt)
    return { lossless: true, strip: true } if attempt[:lossless]

    { quality: attempt[:quality], strip: true }
  end

  def rename_to(extension)
    base = File.basename(@filename, File.extname(@filename))
    base = 'image' if base.blank?
    "#{base}#{extension}"
  end
end
