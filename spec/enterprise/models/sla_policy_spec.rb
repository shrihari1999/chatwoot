require 'rails_helper'

RSpec.describe SlaPolicy, type: :model do
  include ActiveJob::TestHelper
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:conversations).dependent(:nullify) }
  end

  describe 'validates_factory' do
    it 'creates valid sla policy object' do
      sla_policy = create(:sla_policy)
      expect(sla_policy.name).to eq 'sla_1'
      expect(sla_policy.first_response_time_threshold).to eq 2000
      expect(sla_policy.description).to eq 'SLA policy for enterprise customers'
      expect(sla_policy.next_response_time_threshold).to eq 1000
      expect(sla_policy.resolution_time_threshold).to eq 3000
      expect(sla_policy.only_during_business_hours).to be false
    end
  end

  describe 'audit log' do
    let!(:sla_policy) { create(:sla_policy, account: account) }

    context 'when sla policy is created' do
      it 'has associated audit log created' do
        expect(Audited::Audit.where(auditable_type: 'SlaPolicy', action: 'create').count).to eq 1
      end
    end

    context 'when sla policy is updated' do
      it 'has associated audit log created' do
        sla_policy.update(name: 'updated sla')
        expect(Audited::Audit.where(auditable_type: 'SlaPolicy', action: 'update').count).to eq 1
      end
    end

    context 'when sla policy is destroyed via the audited gem' do
      it 'does not produce a duplicate destroy audit (DeleteObjectJob owns destroy)' do
        sla_policy.destroy!
        expect(Audited::Audit.where(auditable_type: 'SlaPolicy', action: 'destroy').count).to eq 0
      end
    end
  end
end
