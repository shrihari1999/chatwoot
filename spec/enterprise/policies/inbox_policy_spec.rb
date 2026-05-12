# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Enterprise::InboxPolicy', type: :policy do
  subject(:inbox_policy) { InboxPolicy }

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }

  let(:custom_role) { create(:custom_role, account: account, permissions: ['settings_manage']) }
  let(:agent_with_role) { create(:user) }
  let(:agent_with_role_account_user) do
    create(:account_user, user: agent_with_role, account: account, role: :agent, custom_role: custom_role)
  end
  let(:agent_with_role_context) do
    { user: agent_with_role, account: account, account_user: agent_with_role_account_user }
  end

  permissions :update?, :avatar?, :sync_templates?, :set_agent_bot?, :health?, :reset_secret? do
    context 'when agent has settings_manage permission' do
      it { expect(inbox_policy).to permit(agent_with_role_context, inbox) }
    end
  end

  permissions :create?, :destroy?, :campaigns? do
    context 'when agent has settings_manage permission' do
      it { expect(inbox_policy).not_to permit(agent_with_role_context, inbox) }
    end
  end
end
