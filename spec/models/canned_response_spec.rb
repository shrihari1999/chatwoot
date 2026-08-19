# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CannedResponse, type: :model do
  let(:account) { create(:account) }
  let(:category) { create(:canned_response_category, account: account) }

  describe 'validations' do
    it 'is valid with content and no files' do
      cr = build(:canned_response, account: account, category: category, content: 'Hello', short_code: 'hi')
      expect(cr).to be_valid
    end

    it 'is invalid without content and without files' do
      cr = build(:canned_response, account: account, category: category, content: nil, short_code: 'hi')
      expect(cr).not_to be_valid
      expect(cr.errors[:base]).to include('A canned response must have a message or at least one image attachment')
    end

    it 'is valid without content when pending_file_ids are present' do
      cr = build(:canned_response, account: account, category: category, content: nil, short_code: 'hi')
      cr.pending_file_ids = ['fake_signed_id']
      expect(cr).to be_valid
    end

    it 'is invalid without content when pending_file_ids is empty' do
      cr = build(:canned_response, account: account, category: category, content: nil, short_code: 'hi')
      cr.pending_file_ids = []
      expect(cr).not_to be_valid
      expect(cr.errors[:base]).to include('A canned response must have a message or at least one image attachment')
    end

    it 'is valid without content when files are attached' do
      cr = create(:canned_response, account: account, category: category, content: 'temp', short_code: 'img')
      cr.files.attach(
        io: StringIO.new('x'),
        filename: 'a.png',
        content_type: 'image/png'
      )
      cr.content = nil
      expect(cr).to be_valid
    end

    it 'requires short_code' do
      cr = build(:canned_response, account: account, category: category, content: 'Hello', short_code: nil)
      expect(cr).not_to be_valid
      expect(cr.errors[:short_code]).to be_present
    end

    it 'requires a category' do
      cr = build(:canned_response, account: account, category: nil, content: 'Hello', short_code: 'hi')
      expect(cr).not_to be_valid
      expect(cr.errors[:category]).to be_present
    end

    it 'rejects duplicate short_code across categories' do
      other_category = create(:canned_response_category, account: account)
      create(:canned_response, account: account, category: category, content: 'Hello', short_code: 'dup')
      cr = build(:canned_response, account: account, category: other_category, content: 'World', short_code: 'dup')
      expect(cr).not_to be_valid
      expect(cr.errors[:short_code]).to be_present
    end

    it 'rejects duplicate short_code within the same category' do
      create(:canned_response, account: account, category: category, content: 'Hello', short_code: 'dup')
      cr = build(:canned_response, account: account, category: category, content: 'World', short_code: 'dup')
      expect(cr).not_to be_valid
      expect(cr.errors[:short_code]).to be_present
    end

    it 'allows the same short_code in a different account' do
      other_account = create(:account)
      create(:canned_response, account: account, category: category, content: 'Hello', short_code: 'dup')
      cr = build(:canned_response, account: other_account,
                                   category: create(:canned_response_category, account: other_account),
                                   content: 'World', short_code: 'dup')
      expect(cr).to be_valid
    end

    it 'rejects a category from a different account' do
      foreign_category = create(:canned_response_category, account: create(:account))
      cr = build(:canned_response, account: account, category: foreign_category, content: 'Hello', short_code: 'hi')
      expect(cr).not_to be_valid
      expect(cr.errors[:category]).to be_present
    end
  end

  describe '#file_base_data' do
    let(:canned_response) do
      create(:canned_response, account: account, category: category, content: 'Hello', short_code: 'hi')
    end

    def attach(filename, content_type, io)
      canned_response.files.attach(io: io, filename: filename, content_type: content_type)
      canned_response.file_base_data.last
    end

    it 'exposes a variant thumb_url distinct from the original for a representable image' do
      data = attach('card.png', 'image/png', Rails.root.join('spec/assets/avatar.png').open)

      expect(data[:thumb_url]).to be_present
      expect(data[:thumb_url]).not_to eq(data[:file_url])
      expect(data[:thumb_url]).to include('representations')
    end

    it 'keeps file_url pointing at the untouched original' do
      data = attach('card.png', 'image/png', Rails.root.join('spec/assets/avatar.png').open)

      expect(data[:file_url]).to include('/blobs/')
      expect(data[:file_url]).not_to include('representations')
    end

    it 'falls back to the original url when the attachment is not representable' do
      data = attach('doc.txt', 'text/plain', StringIO.new('not an image'))

      expect(data[:thumb_url]).to eq(data[:file_url])
    end

    # The picker and composer both render thumb_url, but the outgoing message is built
    # from blob_signed_id. If that ever changed, customers would receive 96px thumbnails.
    it 'still exposes the blob signed id used for sending' do
      data = attach('card.png', 'image/png', Rails.root.join('spec/assets/avatar.png').open)

      expect(data[:blob_signed_id]).to be_present
    end
  end

  describe 'content variants' do
    let(:canned_response) do
      create(:canned_response, account: account, category: category, content: 'hello one', short_code: 'hi')
    end

    describe '#contents' do
      it 'returns the main wording followed by its variants' do
        canned_response.update!(content_variants: ['hello two', 'hello three'])

        expect(canned_response.contents).to eq(['hello one', 'hello two', 'hello three'])
      end

      it 'drops blank variants' do
        canned_response.update!(content_variants: ['hello two', '', '  '])

        expect(canned_response.contents).to eq(['hello one', 'hello two'])
      end

      it 'returns just the main wording when there are no variants' do
        expect(canned_response.contents).to eq(['hello one'])
      end
    end

    describe '#advance_content_variant!' do
      it 'walks the cursor through the wordings and wraps around' do
        canned_response.update!(content_variants: ['hello two', 'hello three'])

        expect(Array.new(4) { canned_response.advance_content_variant! }).to eq([1, 2, 0, 1])
      end

      it 'still resolves to a real wording when a variant is removed under a high cursor' do
        canned_response.update!(content_variants: ['hello two', 'hello three'])
        2.times { canned_response.advance_content_variant! }
        expect(canned_response.reload.content_variant_cursor).to eq(2)

        canned_response.update!(content_variants: [])

        # The cursor is left where it was -- callers take it modulo the wording count,
        # so a stale value can never point past the end of the list.
        wordings = canned_response.contents
        expect(wordings[canned_response.content_variant_cursor % wordings.size]).to eq('hello one')
        expect(canned_response.advance_content_variant!).to eq(0)
      end

      it 'does not move the cursor when there is only one wording' do
        expect(canned_response.advance_content_variant!).to eq(0)
        expect(canned_response.reload.content_variant_cursor).to eq(0)
      end

      it 'does not touch updated_at' do
        canned_response.update!(content_variants: ['hello two'])
        expect { canned_response.advance_content_variant! }.not_to(change { canned_response.reload.updated_at })
      end
    end

    describe 'validation' do
      it 'rejects more variants than the limit' do
        canned_response.content_variants = Array.new(CannedResponse::CONTENT_VARIANTS_LIMIT + 1, 'x')

        expect(canned_response).not_to be_valid
        expect(canned_response.errors.full_messages.join).to include('cannot hold more than')
      end

      it 'rejects a value that is not a list of messages' do
        canned_response.content_variants = { first: 'hello two' }

        expect(canned_response).not_to be_valid
        expect(canned_response.errors.full_messages.join).to include('must be a list of messages')
      end
    end
  end
end
