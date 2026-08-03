require 'rails_helper'

describe Attachments::ImageCompressor do
  # Tempfile unlinks itself when garbage collected, so holding only the path leaves a
  # dangling filename. Keep the objects alive for the duration of the example.
  let(:retained_tempfiles) { [] }

  # Built at runtime rather than committed: the point is a genuinely over-threshold
  # image, and a >8 MB binary has no business in the repo. Photographic noise is used
  # so the encoders cannot trivially collapse it.
  def noisy_image(width:, height:, alpha: false, format: 'png')
    bands = alpha ? 4 : 3
    image = Vips::Image.gaussnoise(width, height)
    image = Vips::Image.bandjoin([image] * bands).cast(:uchar)
    tempfile = Tempfile.new(['fixture', ".#{format}"], binmode: true)
    retained_tempfiles << tempfile
    image.write_to_file(tempfile.path)
    tempfile.path
  end

  def compress(path, content_type:, filename: File.basename(path))
    File.open(path, 'rb') do |file|
      described_class.new(io: file, filename: filename, content_type: content_type).compress
    end
  end

  describe 'files that need no work' do
    it 'returns nil for an image under the threshold' do
      path = noisy_image(width: 200, height: 200)

      expect(compress(path, content_type: 'image/png')).to be_nil
    end

    it 'returns nil for a non-image content type' do
      file = Tempfile.new(['doc', '.pdf'], binmode: true)
      retained_tempfiles << file
      file.write('x' * (described_class::MAX_BYTES + 1))
      file.flush

      result = described_class.new(io: file, filename: 'doc.pdf', content_type: 'application/pdf').compress

      expect(result).to be_nil
    end

    it 'returns nil for an animated gif rather than flattening it' do
      file = Tempfile.new(['anim', '.gif'], binmode: true)
      retained_tempfiles << file
      file.write('x' * (described_class::MAX_BYTES + 1))
      file.flush

      result = described_class.new(io: file, filename: 'anim.gif', content_type: 'image/gif').compress

      expect(result).to be_nil
    end
  end

  describe 'oversized images' do
    it 'brings an opaque PNG under the threshold losslessly when resizing is enough' do
      path = noisy_image(width: 4000, height: 3000)
      expect(File.size(path)).to be > described_class::MAX_BYTES

      result = compress(path, content_type: 'image/png', filename: 'SeaTalk_IMG_20260723.png')

      expect(result).not_to be_nil
      expect(result[:io].size).to be <= described_class::MAX_BYTES
      expect(result[:lossless]).to be(true)
      expect(result[:content_type]).to eq('image/png')
      expect(result[:filename]).to eq('SeaTalk_IMG_20260723.png')
    end

    it 'falls back to lossy JPEG only when lossless cannot fit' do
      # A threshold no candidate can meet, so the whole ladder is walked and the final
      # lossy attempt wins. Pinning the behaviour this way avoids depending on how well
      # a particular synthetic image happens to compress.
      stub_const("#{described_class}::MAX_BYTES", 1.kilobyte)
      path = noisy_image(width: 3000, height: 3000)

      result = compress(path, content_type: 'image/png', filename: 'huge.png')

      expect(result).not_to be_nil
      expect(result[:lossless]).to be(false)
      expect(result[:content_type]).to eq('image/jpeg')
      expect(result[:filename]).to eq('huge.jpg')
    end

    it 'keeps a transparent PNG as PNG so alpha survives' do
      path = noisy_image(width: 4000, height: 3000, alpha: true)
      expect(File.size(path)).to be > described_class::MAX_BYTES

      result = compress(path, content_type: 'image/png', filename: 'logo.png')

      expect(result).not_to be_nil
      expect(result[:lossless]).to be(true)
      expect(result[:content_type]).to eq('image/png')
      expect(result[:filename]).to eq('logo.png')
      expect(Vips::Image.new_from_buffer(result[:io].read, '')).to have_attributes(has_alpha?: true)
    end

    it 'caps the longest edge at the first attempt dimension' do
      path = noisy_image(width: 4000, height: 3000)

      result = compress(path, content_type: 'image/png')
      image = Vips::Image.new_from_buffer(result[:io].read, '')

      expect([image.width, image.height].max).to eq(described_class::MAX_DIMENSION)
    end

    it 'never emits webp, which the TikTok DM send service rejects' do
      path = noisy_image(width: 4000, height: 3000)

      result = compress(path, content_type: 'image/png')

      expect(result[:content_type]).not_to eq('image/webp')
    end

    it 'preserves the JPEG content type for an oversized JPEG' do
      # A JPEG source can never be re-encoded truly losslessly, so its first attempt is
      # the near-lossless quality rather than a lossless save.
      stub_const("#{described_class}::MAX_BYTES", 100.kilobytes)
      path = noisy_image(width: 3000, height: 3000, format: 'jpg')

      result = compress(path, content_type: 'image/jpeg', filename: 'photo.jpg')

      expect(result).not_to be_nil
      expect(result[:content_type]).to eq('image/jpeg')
      expect(result[:filename]).to eq('photo.jpg')
    end
  end

  describe 'failure handling' do
    it 'returns nil instead of raising when the image cannot be decoded' do
      file = Tempfile.new(['broken', '.png'], binmode: true)
      retained_tempfiles << file
      file.write('not really a png' * ((described_class::MAX_BYTES / 16) + 1))
      file.flush

      service = described_class.new(io: file, filename: 'broken.png', content_type: 'image/png')

      result = nil
      expect { result = service.compress }.not_to raise_error
      expect(result).to be_nil
    end
  end
end
