require 'rails_helper'

RSpec.describe 'Enterprise Audit API', type: :request do
  let!(:account) { create(:account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let!(:inbox) { create(:inbox, account: account) }

  describe 'GET /api/v1/accounts/{account.id}/audit_logs' do
    context 'when it is an un-authenticated user' do
      it 'does not fetch audit logs associated with the account' do
        get "/api/v1/accounts/#{account.id}/audit_logs",
            as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated normal user' do
      let(:user) { create(:user, account: account) }

      it 'fetches audit logs associated with the account' do
        get "/api/v1/accounts/#{account.id}/audit_logs",
            headers: user.create_new_auth_token,
            as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent with settings_manage custom role' do
      let(:custom_role) { create(:custom_role, account: account, permissions: ['settings_manage']) }
      let(:settings_agent) { create(:user) }

      before do
        create(:account_user, user: settings_agent, account: account, role: :agent, custom_role: custom_role)
        account.enable_features(:audit_logs)
        account.save!
      end

      it 'fetches audit logs associated with the account' do
        get "/api/v1/accounts/#{account.id}/audit_logs",
            headers: settings_agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
      end
    end

    # check for response in parse
    context 'when it is an authenticated admin user' do
      it 'returns empty array if feature is not enabled' do
        account.disable_features(:audit_logs)
        account.save!

        get "/api/v1/accounts/#{account.id}/audit_logs",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['audit_logs']).to eql([])
      end

      it 'fetches audit logs associated with the account' do
        account.enable_features(:audit_logs)
        account.save!

        get "/api/v1/accounts/#{account.id}/audit_logs",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        inbox_log = json_response['audit_logs'].find { |l| l['auditable_type'] == 'Inbox' }
        expect(inbox_log).not_to be_nil
        expect(inbox_log['action']).to eql('create')
        expect(inbox_log['audited_changes']['name']).to eql(inbox.name)
        expect(inbox_log['associated_id']).to eql(account.id)
        expect(json_response['current_page']).to be(1)
        expect(json_response['total_entries']).to be >= 1
      end
    end
  end
end
