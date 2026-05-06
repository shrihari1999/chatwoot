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

    it 'allows the same short_code in different categories' do
      other_category = create(:canned_response_category, account: account)
      create(:canned_response, account: account, category: category, content: 'Hello', short_code: 'dup')
      cr = build(:canned_response, account: account, category: other_category, content: 'World', short_code: 'dup')
      expect(cr).to be_valid
    end

    it 'rejects duplicate short_code within the same category' do
      create(:canned_response, account: account, category: category, content: 'Hello', short_code: 'dup')
      cr = build(:canned_response, account: account, category: category, content: 'World', short_code: 'dup')
      expect(cr).not_to be_valid
      expect(cr.errors[:short_code]).to be_present
    end

    it 'rejects a category from a different account' do
      foreign_category = create(:canned_response_category, account: create(:account))
      cr = build(:canned_response, account: account, category: foreign_category, content: 'Hello', short_code: 'hi')
      expect(cr).not_to be_valid
      expect(cr.errors[:category]).to be_present
    end
  end
end
