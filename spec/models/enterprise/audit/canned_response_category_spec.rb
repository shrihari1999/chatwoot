require 'rails_helper'

RSpec.describe 'CannedResponseCategory Audit', type: :model do
  let(:account) { create(:account) }

  describe 'audit logging' do
    it 'creates an audit log when a canned response category is created' do
      expect do
        create(:canned_response_category, account: account)
      end.to change(Audited::Audit, :count).by(1)

      audit = Audited::Audit.last
      expect(audit.auditable_type).to eq('CannedResponseCategory')
      expect(audit.action).to eq('create')
    end

    it 'creates an audit log when a canned response category is updated' do
      category = create(:canned_response_category, account: account)

      expect do
        category.update!(name: 'Updated name')
      end.to change(Audited::Audit, :count).by(1)

      audit = Audited::Audit.last
      expect(audit.auditable_type).to eq('CannedResponseCategory')
      expect(audit.action).to eq('update')
    end

    it 'creates an audit log when a canned response category is destroyed' do
      category = create(:canned_response_category, account: account)

      expect do
        category.destroy!
      end.to change(Audited::Audit, :count).by(1)

      audit = Audited::Audit.last
      expect(audit.auditable_type).to eq('CannedResponseCategory')
      expect(audit.action).to eq('destroy')
    end
  end
end
