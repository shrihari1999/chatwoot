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
  end

  context 'when unauthenticated' do
    it 'returns 401' do
      post react_url, params: { emoji: '❤️' }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
