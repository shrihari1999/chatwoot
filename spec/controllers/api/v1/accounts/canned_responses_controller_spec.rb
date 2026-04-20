require 'rails_helper'

RSpec.describe 'Canned Responses API', type: :request do
  let(:account) { create(:account) }

  before do
    create(:canned_response, account: account, content: 'Hey {{ contact.name }}, Thanks for reaching out', short_code: 'name-short-code')
  end

  def expected_payload(canned_responses)
    canned_responses.map do |cr|
      cr.as_json.merge(
        'category' => cr.category ? cr.category.as_json(only: [:id, :name]) : nil
      )
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/canned_responses' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/canned_responses"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'returns all the canned responses' do
        get "/api/v1/accounts/#{account.id}/canned_responses",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq(expected_payload(account.canned_responses))
      end

      it 'returns all the canned responses the user searched for' do
        cr1 = account.canned_responses.first
        create(:canned_response, account: account, content: 'Great! Looking forward', short_code: 'short-code')
        cr2 = create(:canned_response, account: account, content: 'Thanks for reaching out', short_code: 'content-with-thanks')
        cr3 = create(:canned_response, account: account, content: 'Thanks for reaching out', short_code: 'Thanks')

        params = { search: 'thanks' }

        get "/api/v1/accounts/#{account.id}/canned_responses",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq(expected_payload([cr3, cr2, cr1]))
      end

      context 'when filtering by category_id' do
        let!(:category) { create(:canned_response_category, account: account, name: 'Support') }
        let!(:other_category) { create(:canned_response_category, account: account, name: 'Sales') }
        let!(:categorized_response) do
          create(:canned_response, account: account, content: 'Support content', short_code: 'support-code', category: category)
        end
        let!(:other_categorized_response) do
          create(:canned_response, account: account, content: 'Sales content', short_code: 'sales-code', category: other_category)
        end

        it 'returns only canned responses for the given category' do
          get "/api/v1/accounts/#{account.id}/canned_responses",
              params: { category_id: category.id },
              headers: agent.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:success)
          body = response.parsed_body
          expect(body.length).to eq(1)
          expect(body.first['id']).to eq(categorized_response.id)
          expect(body.first['category']).to eq({ 'id' => category.id, 'name' => category.name })
        end

        it 'includes the category object in the response when category is set' do
          get "/api/v1/accounts/#{account.id}/canned_responses",
              headers: agent.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:success)
          body = response.parsed_body
          categorized = body.find { |cr| cr['id'] == categorized_response.id }
          expect(categorized['category']).to eq({ 'id' => category.id, 'name' => category.name })

          uncategorized = body.find { |cr| cr['id'] == account.canned_responses.find_by(short_code: 'name-short-code').id }
          expect(uncategorized['category']).to be_nil
        end
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/canned_responses' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/canned_responses"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'creates a new canned response' do
        params = { short_code: 'short', content: 'content' }

        post "/api/v1/accounts/#{account.id}/canned_responses",
             params: params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(account.canned_responses.count).to eq(2)
      end

      it 'creates a new canned response with a category' do
        category = create(:canned_response_category, account: account, name: 'Support')
        params = { short_code: 'short', content: 'content', category_id: category.id }

        post "/api/v1/accounts/#{account.id}/canned_responses",
             params: params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        body = response.parsed_body
        expect(body['category']).to eq({ 'id' => category.id, 'name' => category.name })
        expect(account.canned_responses.last.category_id).to eq(category.id)
      end
    end
  end

  describe 'PUT /api/v1/accounts/{account.id}/canned_responses/:id' do
    let(:canned_response) { CannedResponse.last }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        put "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'updates an existing canned response' do
        params = { short_code: 'B' }

        put "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(canned_response.reload.short_code).to eq('B')
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/canned_responses/:id' do
    let(:canned_response) { CannedResponse.last }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'destroys the canned response' do
        delete "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
               headers: agent.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:success)
        expect(CannedResponse.count).to eq(0)
      end
    end
  end
end
