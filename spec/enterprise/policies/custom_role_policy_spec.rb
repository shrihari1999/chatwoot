# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CustomRolePolicy, type: :policy do
  subject(:custom_role_policy) { described_class }

  let(:account) { create(:account) }
  let(:target_role) { create(:custom_role, account: account) }

  let(:settings_manage_role) { create(:custom_role, account: account, permissions: ['settings_manage']) }
  let(:settings_agent) { create(:user) }
  let(:settings_agent_account_user) do
    create(:account_user, user: settings_agent, account: account, role: :agent, custom_role: settings_manage_role)
  end
  let(:settings_agent_context) do
    { user: settings_agent, account: account, account_user: settings_agent_account_user }
  end

  let(:plain_agent) { create(:user) }
  let(:plain_agent_account_user) do
    create(:account_user, user: plain_agent, account: account, role: :agent)
  end
  let(:plain_agent_context) do
    { user: plain_agent, account: account, account_user: plain_agent_account_user }
  end

  permissions :index?, :show? do
    context 'when agent has settings_manage permission' do
      it { expect(custom_role_policy).to permit(settings_agent_context, target_role) }
    end

    context 'when agent does not have settings_manage permission' do
      it { expect(custom_role_policy).not_to permit(plain_agent_context, target_role) }
    end
  end

  permissions :create?, :update?, :destroy? do
    context 'when agent has settings_manage permission' do
      it { expect(custom_role_policy).not_to permit(settings_agent_context, target_role) }
    end
  end
end
