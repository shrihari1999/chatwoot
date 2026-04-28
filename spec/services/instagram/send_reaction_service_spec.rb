# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Instagram::SendReactionService do
  let(:channel) do
    instance_double(Channel::Instagram,
                    instagram_id: 'ig_123',
                    access_token: 'token_abc')
  end
  let(:inbox)        { instance_double('Inbox', channel: channel, id: 2) }
  let(:contact)      { instance_double('Contact') }
  let(:conversation) { instance_double('Conversation', inbox: inbox, inbox_id: 2, contact: contact) }
  let(:message)      { instance_double('Message', conversation: conversation, source_id: 'mid.def', id: 99) }
  let(:success_response) { instance_double(HTTParty::Response, success?: true) }

  before do
    allow(contact).to receive(:get_source_id).with(2).and_return('igsid_xyz')
    allow(GlobalConfigService).to receive(:load).with('INSTAGRAM_API_VERSION', 'v22.0').and_return('v22.0')
  end

  describe '#perform' do
    it 'posts react request to Instagram API' do
      allow(HTTParty).to receive(:post).and_return(success_response)

      described_class.new(message: message, emoji: '😂', action: 'react').perform

      expect(HTTParty).to have_received(:post).with(
        'https://graph.instagram.com/v22.0/ig_123/messages',
        body: {
          recipient: { id: 'igsid_xyz' },
          sender_action: 'react',
          payload: { message_id: 'mid.def', reaction: '😂' }
        },
        query: { access_token: 'token_abc' }
      )
    end

    it 'posts unreact request without reaction key' do
      allow(HTTParty).to receive(:post).and_return(success_response)

      described_class.new(message: message, emoji: '😂', action: 'unreact').perform

      expect(HTTParty).to have_received(:post).with(
        'https://graph.instagram.com/v22.0/ig_123/messages',
        body: {
          recipient: { id: 'igsid_xyz' },
          sender_action: 'unreact',
          payload: { message_id: 'mid.def' }
        },
        query: { access_token: 'token_abc' }
      )
    end

    it 'is a no-op when igsid is blank' do
      allow(contact).to receive(:get_source_id).and_return(nil)
      allow(HTTParty).to receive(:post)

      described_class.new(message: message, emoji: '😂').perform

      expect(HTTParty).not_to have_received(:post)
    end
  end
end
