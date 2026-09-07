require 'rails_helper'

RSpec.describe 'CannedResponse Audit', type: :model do
  let(:account) { create(:account) }
  let(:category) { create(:canned_response_category, account: account) }

  describe 'audit logging' do
    it 'creates an audit log when a canned response is created' do
      category

      expect do
        create(:canned_response, account: account, category: category)
      end.to change(Audited::Audit, :count).by(1)

      audit = Audited::Audit.last
      expect(audit.auditable_type).to eq('CannedResponse')
      expect(audit.action).to eq('create')
    end

    it 'creates an audit log when a canned response is updated' do
      canned_response = create(:canned_response, account: account, category: category)

      expect do
        canned_response.update!(content: 'updated content')
      end.to change(Audited::Audit, :count).by(1)

      audit = Audited::Audit.last
      expect(audit.auditable_type).to eq('CannedResponse')
      expect(audit.action).to eq('update')
    end

    it 'creates an audit log when a canned response is destroyed' do
      canned_response = create(:canned_response, account: account, category: category)

      expect do
        canned_response.destroy!
      end.to change(Audited::Audit, :count).by(1)

      audit = Audited::Audit.last
      expect(audit.auditable_type).to eq('CannedResponse')
      expect(audit.action).to eq('destroy')
    end
  end
end
