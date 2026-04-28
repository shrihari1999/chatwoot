# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /api/v1/accounts/:account_id/conversations/:conversation_id/messages/:id/react' do
  let(:account)      { create(:account) }
  let(:inbox)        { create(:inbox, account: account) }
  let(:contact)      { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:message)      { create(:message, conversation: conversation, inbox: inbox, source_id: 'mid.test') }
  let(:agent)        { create(:user, account: account, role: :agent) }

  before do
    create(:inbox_member, inbox: inbox, user: agent)
  end

  def react_url
    "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/messages/#{message.id}/react"
  end

  context 'when authenticated as agent' do
    it 'returns 200 and applies reaction locally' do
      post react_url,
           params: { emoji: '❤️', reaction_action: 'react' },
           headers: { 'api_access_token' => agent.access_token.token }

      expect(response).to have_http_status(:ok)
      expect(message.reload.reactions).to include('❤️')
    end

    it 'returns 200 and applies unreact' do
      message.apply_reaction!(emoji: '❤️', sender_id: "agent:#{agent.id}", action: 'react')

      post react_url,
           params: { emoji: '❤️', reaction_action: 'unreact' },
           headers: { 'api_access_token' => agent.access_token.token }

      expect(response).to have_http_status(:ok)
      expect(message.reload.reactions).not_to include('❤️')
    end

    it 'defaults reaction_action to react when not provided' do
      post react_url,
           params: { emoji: '👍' },
           headers: { 'api_access_token' => agent.access_token.token }

      expect(response).to have_http_status(:ok)
      expect(message.reload.reactions).to include('👍')
    end

    context 'when on a Facebook inbox' do
      let(:fb_channel) do
        Channel::FacebookPage.create!(
          account: account,
          page_id: SecureRandom.uuid,
          page_access_token: SecureRandom.uuid,
          user_access_token: SecureRandom.uuid
        )
      end
      let(:fb_inbox)        { create(:inbox, account: account, channel: fb_channel) }
      let(:fb_conversation) { create(:conversation, account: account, inbox: fb_inbox, contact: contact) }
      let(:fb_message)      { create(:message, conversation: fb_conversation, inbox: fb_inbox, source_id: 'mid.fb') }

      before do
        create(:inbox_member, inbox: fb_inbox, user: agent)
      end

      def fb_react_url
        "/api/v1/accounts/#{account.id}/conversations/#{fb_conversation.display_id}/messages/#{fb_message.id}/react"
      end

      it 'persists the reaction locally without calling platform APIs' do
        expect(Facebook::SendReactionService).not_to receive(:new)

        post fb_react_url,
             params: { emoji: '❤️', reaction_action: 'react' },
             headers: { 'api_access_token' => agent.access_token.token }

        expect(response).to have_http_status(:ok)
        expect(fb_message.reload.reactions).to include('❤️')
      end
    end

    context 'when on an Instagram inbox' do
      let(:ig_channel) do
        instagram_id = SecureRandom.hex(16)
        access_token = SecureRandom.hex(32)
        WebMock::API.stub_request(:post, "https://graph.instagram.com/v22.0/#{instagram_id}/subscribed_apps")
                    .with(query: hash_including({}))
                    .to_return(status: 200, body: '', headers: {})
        Channel::Instagram.create!(
          account: account,
          access_token: access_token,
          instagram_id: instagram_id,
          expires_at: 60.days.from_now
        )
      end
      let(:ig_inbox)        { create(:inbox, account: account, channel: ig_channel) }
      let(:ig_conversation) { create(:conversation, account: account, inbox: ig_inbox, contact: contact) }
      let(:ig_message)      { create(:message, conversation: ig_conversation, inbox: ig_inbox, source_id: 'mid.ig') }

      before do
        create(:inbox_member, inbox: ig_inbox, user: agent)
      end

      def ig_react_url
        "/api/v1/accounts/#{account.id}/conversations/#{ig_conversation.display_id}/messages/#{ig_message.id}/react"
      end

      it 'persists the reaction locally without calling platform APIs' do
        expect(Instagram::SendReactionService).not_to receive(:new)

        post ig_react_url,
             params: { emoji: '😂', reaction_action: 'react' },
             headers: { 'api_access_token' => agent.access_token.token }

        expect(response).to have_http_status(:ok)
        expect(ig_message.reload.reactions).to include('😂')
      end
    end
  end

  context 'when unauthenticated' do
    it 'returns 401' do
      post react_url, params: { emoji: '❤️' }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
