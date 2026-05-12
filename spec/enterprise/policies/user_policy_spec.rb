# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Enterprise::UserPolicy', type: :policy do
  subject(:user_policy) { UserPolicy }

  let(:account) { create(:account) }
  let(:target_user) { create(:user, account: account) }

  let(:custom_role) { create(:custom_role, account: account, permissions: ['settings_manage']) }
  let(:agent_with_role) { create(:user) }
  let(:agent_with_role_account_user) do
    create(:account_user, user: agent_with_role, account: account, role: :agent, custom_role: custom_role)
  end
  let(:agent_with_role_context) do
    { user: agent_with_role, account: account, account_user: agent_with_role_account_user }
  end

  permissions :create?, :update?, :destroy?, :bulk_create? do
    context 'when agent with settings_manage permission' do
      it { expect(user_policy).to permit(agent_with_role_context, target_user) }
    end
  end
end
