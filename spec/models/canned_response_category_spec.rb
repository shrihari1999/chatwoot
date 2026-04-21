# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CannedResponseCategory, type: :model do
  let(:account) { create(:account) }

  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:canned_responses).with_foreign_key(:category_id) }
  end

  describe 'validations' do
    subject { build(:canned_response_category, account: account) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:account_id) }
  end
end
