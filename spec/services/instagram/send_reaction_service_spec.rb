# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Instagram::SendReactionService do
  let(:account)      { instance_double(Account) }
  let(:channel)      { instance_double(Channel::Instagram, instagram_id: '17841443698384602', access_token: 'IG_TOKEN_xyz') }
  let(:inbox)        { instance_double(Inbox, channel: channel, id: 1) }
  let(:contact)      { instance_double(Contact) }
  let(:conversation) { instance_double(Conversation, inbox: inbox, inbox_id: 1, contact: contact) }
  let(:message)      { instance_double(Message, conversation: conversation, source_id: 'mid.abc', id: 42, account: account) }

  let(:expected_url)     { 'https://graph.instagram.com/v22.0/17841443698384602/messages' }
  let(:success_response) { instance_double(HTTParty::Response, success?: true, parsed_response: { 'recipient_id' => 'igsid_xyz' }) }

  before do
    allow(contact).to receive(:get_source_id).with(1).and_return('igsid_xyz')
    stub_const('GlobalConfigService', Class.new { def self.load(_, default = nil) = default })
  end

  describe '#perform' do
    # graph.instagram.com's reaction endpoint rejects form-encoded payloads
    # with subcode 2534015 ("Invalid message data") because the nested
    # payload[message_id]/payload[reaction] hash doesn't round-trip.  The
    # JSON body + Authorization Bearer header is the documented shape that
    # actually works.  These tests pin that shape so the regression cannot
    # come back silently.
    it 'POSTs JSON body with Authorization Bearer header' do
      allow(HTTParty).to receive(:post).and_return(success_response)

      described_class.new(message: message, emoji: '❤️', action: 'react').perform

      expect(HTTParty).to have_received(:post).with(
        expected_url,
        body: { recipient: { id: 'igsid_xyz' }, sender_action: 'react', payload: { message_id: 'mid.abc', reaction: '❤️' } }.to_json,
        headers: { 'Content-Type' => 'application/json', 'Authorization' => 'Bearer IG_TOKEN_xyz' }
      )
    end

    it 'omits reaction key on unreact' do
      allow(HTTParty).to receive(:post).and_return(success_response)

      described_class.new(message: message, emoji: '❤️', action: 'unreact').perform

      expect(HTTParty).to have_received(:post).with(
        expected_url,
        body: { recipient: { id: 'igsid_xyz' }, sender_action: 'unreact', payload: { message_id: 'mid.abc' } }.to_json,
        headers: hash_including('Content-Type' => 'application/json', 'Authorization' => 'Bearer IG_TOKEN_xyz')
      )
    end

    it 'is a no-op when igsid is blank' do
      allow(contact).to receive(:get_source_id).and_return(nil)
      allow(HTTParty).to receive(:post)

      result = described_class.new(message: message, emoji: '❤️', action: 'react').perform

      expect(HTTParty).not_to have_received(:post)
      expect(result).to be false
    end

    it 'is a no-op when mid is blank' do
      allow(message).to receive(:source_id).and_return(nil)
      allow(HTTParty).to receive(:post)

      result = described_class.new(message: message, emoji: '❤️', action: 'react').perform

      expect(HTTParty).not_to have_received(:post)
      expect(result).to be false
    end

    it 'tracks and re-raises on non-success Meta responses' do
      tracker = instance_double(ChatwootExceptionTracker, capture_exception: true)
      allow(ChatwootExceptionTracker).to receive(:new).and_return(tracker)
      failure = instance_double(HTTParty::Response, success?: false,
                                                    parsed_response: { 'error' => { 'code' => 100, 'message' => 'Invalid message data' } })
      allow(HTTParty).to receive(:post).and_return(failure)

      expect do
        described_class.new(message: message, emoji: '❤️', action: 'react').perform
      end.to raise_error(StandardError, /Invalid message data/)

      expect(tracker).to have_received(:capture_exception)
    end
  end
end
