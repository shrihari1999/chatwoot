# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CannedResponse, type: :model do
  let(:account) { create(:account) }

  describe 'validations' do
    it 'is valid with both content and no files' do
      cr = build(:canned_response, account: account, content: 'Hello', short_code: 'hi')
      expect(cr).to be_valid
    end

    it 'is invalid without content and without files' do
      cr = build(:canned_response, account: account, content: nil, short_code: 'hi')
      expect(cr).not_to be_valid
      expect(cr.errors[:base]).to include('A canned response must have a message or at least one image attachment')
    end

    it 'is valid without content when pending_file_ids are present' do
      cr = build(:canned_response, account: account, content: nil, short_code: 'hi')
      cr.pending_file_ids = ['fake_signed_id']
      expect(cr).to be_valid
    end

    it 'is invalid without content when pending_file_ids is empty' do
      cr = build(:canned_response, account: account, content: nil, short_code: 'hi')
      cr.pending_file_ids = []
      expect(cr).not_to be_valid
      expect(cr.errors[:base]).to include('A canned response must have a message or at least one image attachment')
    end

    it 'requires short_code' do
      cr = build(:canned_response, account: account, content: 'Hello', short_code: nil)
      expect(cr).not_to be_valid
      expect(cr.errors[:short_code]).to be_present
    end

    it 'enforces short_code uniqueness per account' do
      create(:canned_response, account: account, content: 'Hello', short_code: 'dup')
      cr = build(:canned_response, account: account, content: 'World', short_code: 'dup')
      expect(cr).not_to be_valid
    end
  end
end
