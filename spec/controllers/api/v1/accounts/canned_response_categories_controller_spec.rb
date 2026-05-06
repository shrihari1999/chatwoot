# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Canned Response Categories API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:category) { create(:canned_response_category, account: account, name: 'Support') }

  describe 'GET /api/v1/accounts/:account_id/canned_response_categories' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/canned_response_categories"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      it 'returns all categories ordered by name' do
        get "/api/v1/accounts/#{account.id}/canned_response_categories",
            headers: agent.create_new_auth_token
        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body)
        expect(body.map { |c| c['name'] }).to include('Support')
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/canned_response_categories' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/canned_response_categories", params: { name: 'New' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      it 'creates a new category' do
        expect do
          post "/api/v1/accounts/#{account.id}/canned_response_categories",
               params: { name: 'Sales' },
               headers: agent.create_new_auth_token
        end.to change(CannedResponseCategory, :count).by(1)
        expect(response).to have_http_status(:created)
      end

      it 'returns error for duplicate name' do
        post "/api/v1/accounts/#{account.id}/canned_response_categories",
             params: { name: 'Support' },
             headers: agent.create_new_auth_token
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/canned_response_categories/:id' do
    context 'when it is an authenticated user' do
      it 'updates the category name' do
        patch "/api/v1/accounts/#{account.id}/canned_response_categories/#{category.id}",
              params: { name: 'Updated Support' },
              headers: agent.create_new_auth_token
        expect(response).to have_http_status(:success)
        expect(category.reload.name).to eq('Updated Support')
      end
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/canned_response_categories/:id' do
    context 'when it is an authenticated user' do
      it 'deletes the category when empty' do
        expect do
          delete "/api/v1/accounts/#{account.id}/canned_response_categories/#{category.id}",
                 headers: agent.create_new_auth_token
        end.to change(CannedResponseCategory, :count).by(-1)
        expect(response).to have_http_status(:ok)
      end

      it 'rejects deletion when canned responses still belong to the category' do
        create(:canned_response, account: account, category: category, content: 'Hi', short_code: 'hi')

        expect do
          delete "/api/v1/accounts/#{account.id}/canned_response_categories/#{category.id}",
                 headers: agent.create_new_auth_token
        end.not_to change(CannedResponseCategory, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
