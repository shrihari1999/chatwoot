require 'rails_helper'

RSpec.describe 'Canned Responses API', type: :request do
  let(:account) { create(:account) }

  before do
    create(:canned_response, account: account, content: 'Hey {{ contact.name }}, Thanks for reaching out', short_code: 'name-short-code')
  end

  def expected_payload(canned_responses)
    canned_responses.map do |cr|
      # `as_json` may return symbol keys for merged attributes (e.g. `files:`).
      # Use deep_stringify_keys so comparisons against response.parsed_body (all
      # string keys) work correctly.
      cr.as_json.merge(
        'category' => cr.category.as_json(only: [:id, :name])
      ).deep_stringify_keys
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

      # Every row is serialized with its category, so without a preload the index
      # is 1 + N queries — and the Freshchat import left hundreds of rows here.
      it 'preloads categories rather than querying one per canned response' do
        create_list(:canned_response, 3, account: account)

        category_queries = 0
        subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
          category_queries += 1 if payload[:sql]&.include?('canned_response_categories')
        end

        begin
          get "/api/v1/accounts/#{account.id}/canned_responses",
              headers: agent.create_new_auth_token,
              as: :json
        ensure
          ActiveSupport::Notifications.unsubscribe(subscriber)
        end

        expect(response).to have_http_status(:success)
        expect(category_queries).to eq(1)
      end

      it 'returns canned responses whose short_code matches the search term' do
        # `cr1` from the outer `before` block has "Thanks" in content but not in
        # short_code — it must be excluded now that search is short_code-only.
        create(:canned_response, account: account, content: 'Great! Looking forward', short_code: 'short-code')
        cr2 = create(:canned_response, account: account, content: 'Thanks for reaching out', short_code: 'content-with-thanks')
        cr3 = create(:canned_response, account: account, content: 'Thanks for reaching out', short_code: 'Thanks')

        params = { search: 'thanks' }

        get "/api/v1/accounts/#{account.id}/canned_responses",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq(expected_payload([cr3, cr2]))
      end

      # Regression: Postgres rejects NUL bytes in query params with
      # `ArgumentError: string contains null byte`, which 500'd this endpoint in
      # production when an agent pasted into the conversation canned-response picker.
      it 'strips a leading NUL byte and still matches' do
        cr = create(:canned_response, account: account, content: 'Thanks for reaching out', short_code: 'thanks')

        get "/api/v1/accounts/#{account.id}/canned_responses",
            params: { search: "\u0000thanks" },
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq(expected_payload([cr]))
      end

      it 'treats a search of only NUL bytes as no search term' do
        create(:canned_response, account: account, content: 'Great! Looking forward', short_code: 'short-code')

        get "/api/v1/accounts/#{account.id}/canned_responses",
            params: { search: "\u0000\u0000" },
            headers: agent.create_new_auth_token,
            as: :json

        # Stripping happens before the blank check, so this degrades to "no filter"
        # rather than searching for "%%" and ordering by an empty term.
        expect(response).to have_http_status(:success)
        expect(response.parsed_body.length).to eq(account.canned_responses.count)
      end

      # The exact term from the production 500s: a NUL followed by a person emoji.
      # It matches no short_code, so this asserts "no longer raises" -- not matching.
      it 'does not raise on the exact search term that failed in production' do
        create(:canned_response, account: account, content: 'Thanks for reaching out', short_code: 'thanks')

        get "/api/v1/accounts/#{account.id}/canned_responses",
            params: { search: "\u0000\u{1F464}" },
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to be_empty
      end

      # Interior NUL rather than leading: proves stripping preserves the surrounding
      # term so matching still works, not merely that it stops raising.
      it 'strips an interior NUL byte and still matches on the remaining characters' do
        create(:canned_response, account: account, content: 'Great! Looking forward', short_code: 'short-code')
        cr2 = create(:canned_response, account: account, content: 'Thanks for reaching out', short_code: 'content-with-thanks')
        cr3 = create(:canned_response, account: account, content: 'Thanks for reaching out', short_code: 'Thanks')

        get "/api/v1/accounts/#{account.id}/canned_responses",
            params: { search: "tha\u0000nks" },
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq(expected_payload([cr3, cr2]))
      end

      # `?search[]=x` yields an Array, which must not reach String#delete. The
      # is_a?(String) guard passes it through so behaviour is unchanged from before.
      it 'passes a non-String search param through untouched' do
        create(:canned_response, account: account, content: 'Great! Looking forward', short_code: 'short-code')

        get "/api/v1/accounts/#{account.id}/canned_responses",
            params: { search: ['thanks'] },
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
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

        it 'includes the category object in the response' do
          get "/api/v1/accounts/#{account.id}/canned_responses",
              headers: agent.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:success)
          body = response.parsed_body
          categorized = body.find { |cr| cr['id'] == categorized_response.id }
          expect(categorized['category']).to eq({ 'id' => category.id, 'name' => category.name })
        end
      end

      context 'when filtering by category visibility' do
        let(:team) { create(:team, account: account) }
        let(:other_team) { create(:team, account: account) }
        let(:other_user) { create(:user, account: account, role: :agent) }

        let!(:everyone_category) { create(:canned_response_category, account: account, visibility: :everyone) }
        let!(:own_category) { create(:canned_response_category, account: account, visibility: :only_me, user: agent) }
        let!(:other_user_category) { create(:canned_response_category, account: account, visibility: :only_me, user: other_user) }
        let!(:team_category) { create(:canned_response_category, account: account, visibility: :specific_team, team: team) }
        let!(:other_team_category) { create(:canned_response_category, account: account, visibility: :specific_team, team: other_team) }

        let!(:visible_responses) do
          [everyone_category, own_category, team_category].map do |cat|
            create(:canned_response, account: account, category: cat, short_code: "code-#{cat.id}")
          end
        end

        before do
          create(:team_member, user: agent, team: team)
          [other_user_category, other_team_category].each do |cat|
            create(:canned_response, account: account, category: cat, short_code: "hidden-#{cat.id}")
          end
        end

        it 'returns only responses in categories the current user can see' do
          get "/api/v1/accounts/#{account.id}/canned_responses",
              params: { visible: 'true' },
              headers: agent.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:success)
          returned_category_ids = response.parsed_body.filter_map { |cr| cr['category']&.fetch('id') }.uniq
          expect(returned_category_ids).to include(everyone_category.id, own_category.id, team_category.id)
          expect(returned_category_ids).not_to include(other_user_category.id, other_team_category.id)
        end

        it 'returns every response when the visible flag is omitted' do
          get "/api/v1/accounts/#{account.id}/canned_responses",
              headers: agent.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:success)
          returned_category_ids = response.parsed_body.filter_map { |cr| cr['category']&.fetch('id') }.uniq
          expect(returned_category_ids).to include(other_user_category.id, other_team_category.id)
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
        category = create(:canned_response_category, account: account, name: 'Default')
        params = { short_code: 'short', content: 'content', category_id: category.id }

        post "/api/v1/accounts/#{account.id}/canned_responses",
             params: params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(account.canned_responses.count).to eq(2)
      end

      it 'rejects creating a canned response without a category' do
        params = { short_code: 'no-cat', content: 'content' }

        expect do
          post "/api/v1/accounts/#{account.id}/canned_responses",
               params: params,
               headers: agent.create_new_auth_token,
               as: :json
        end.not_to change(account.canned_responses, :count)

        expect(response).to have_http_status(:unprocessable_entity)
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

      it 'rejects creating a canned response with a category from another account' do
        other_account = create(:account)
        foreign_category = create(:canned_response_category, account: other_account, name: 'Foreign')
        params = { short_code: 'cross', content: 'content', category_id: foreign_category.id }

        expect do
          post "/api/v1/accounts/#{account.id}/canned_responses",
               params: params,
               headers: agent.create_new_auth_token,
               as: :json
        end.not_to change(account.canned_responses, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'rolls back the created record when attaching files raises' do
        # An invalid signed blob ID makes `attach_files` raise inside the create
        # transaction; the canned response must not be persisted and a 422 is returned.
        category = create(:canned_response_category, account: account, name: 'Default')
        params = { short_code: 'bad-blob', content: '', category_id: category.id, file_ids: ['not-a-real-signed-id'] }

        expect do
          post "/api/v1/accounts/#{account.id}/canned_responses",
               params: params,
               headers: agent.create_new_auth_token,
               as: :json
        end.not_to change(account.canned_responses, :count)

        expect(account.canned_responses.exists?(short_code: 'bad-blob')).to be(false)
        expect(response).to have_http_status(:unprocessable_entity)
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

      it 'updates the content variants' do
        params = { content_variants: ['hello two', 'hello three'] }

        put "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(canned_response.reload.content_variants).to eq(['hello two', 'hello three'])
        expect(response.parsed_body['content_variants']).to eq(['hello two', 'hello three'])
      end

      it 'rejects more content variants than the limit' do
        params = { content_variants: Array.new(CannedResponse::CONTENT_VARIANTS_LIMIT + 1, 'x') }

        put "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(canned_response.reload.content_variants).to eq([])
      end

      it 'rolls back when clearing both content and file_ids' do
        original_content = canned_response.content
        params = { content: '', file_ids: [] }

        put "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(canned_response.reload.content).to eq(original_content)
      end

      it 'preserves existing files when updating short_code without file_ids key' do
        # Build an image-only canned response (no content) with pending_file_ids set so
        # content_or_files_present validation passes at save time.
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new('fake png data'),
          filename: 'test.png',
          content_type: 'image/png'
        )
        image_only = build(:canned_response, account: account, content: '')
        image_only.pending_file_ids = [blob.signed_id]
        image_only.save!
        image_only.files.attach(blob)
        expect(image_only.files.attached?).to be(true)

        # Update only short_code — no file_ids key in request; existing file must survive
        put "/api/v1/accounts/#{account.id}/canned_responses/#{image_only.id}",
            params: { short_code: 'new-img-code' },
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(image_only.reload.short_code).to eq('new-img-code')
        expect(image_only.files.attached?).to be(true)
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

  describe 'POST /api/v1/accounts/{account.id}/canned_responses/:id/advance_variant' do
    let(:canned_response) { CannedResponse.last }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}/advance_variant"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'moves the cursor on to the next wording' do
        canned_response.update!(content_variants: ['hello two', 'hello three'])

        post "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}/advance_variant",
             headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['content_variant_cursor']).to eq(1)
        expect(canned_response.reload.content_variant_cursor).to eq(1)
      end

      it 'is a no-op when the response has no variants' do
        post "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}/advance_variant",
             headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(canned_response.reload.content_variant_cursor).to eq(0)
      end

      it 'does not leak a canned response from another account' do
        other = create(:canned_response, account: create(:account))

        post "/api/v1/accounts/#{account.id}/canned_responses/#{other.id}/advance_variant",
             headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
