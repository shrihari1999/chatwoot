# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Instagram::MarkAsReadService do
  let(:channel)      { instance_double(Channel::Instagram, instagram_id: '17841443698384602', access_token: 'IG_TOKEN_xyz') }
  let(:inbox)        { instance_double(Inbox, channel: channel, channel_type: 'Channel::Instagram', id: 1) }
  let(:contact)      { instance_double(Contact) }
  let(:conversation) { instance_double(Conversation, inbox: inbox, inbox_id: 1, contact: contact, id: 99) }

  let(:expected_url)     { 'https://graph.instagram.com/v22.0/17841443698384602/messages' }
  let(:success_response) { instance_double(HTTParty::Response, success?: true, parsed_response: { 'recipient_id' => 'igsid_xyz' }) }

  before do
    allow(contact).to receive(:get_source_id).with(1).and_return('igsid_xyz')
    allow(GlobalConfigService).to receive(:load).with('INSTAGRAM_API_VERSION', 'v22.0').and_return('v22.0')
  end

  describe '#perform' do
    it 'POSTs mark_seen as JSON with Authorization Bearer header' do
      allow(HTTParty).to receive(:post).and_return(success_response)

      described_class.new(conversation: conversation).perform

      expect(HTTParty).to have_received(:post).with(
        expected_url,
        body: { recipient: { id: 'igsid_xyz' }, sender_action: 'mark_seen' }.to_json,
        headers: { 'Content-Type' => 'application/json', 'Authorization' => 'Bearer IG_TOKEN_xyz' }
      )
    end

    it 'falls back to the "me" node when instagram_id is blank' do
      allow(channel).to receive(:instagram_id).and_return(nil)
      allow(HTTParty).to receive(:post).and_return(success_response)

      described_class.new(conversation: conversation).perform

      expect(HTTParty).to have_received(:post).with(
        'https://graph.instagram.com/v22.0/me/messages',
        hash_including(body: { recipient: { id: 'igsid_xyz' }, sender_action: 'mark_seen' }.to_json)
      )
    end

    it 'is a no-op when igsid is blank' do
      allow(contact).to receive(:get_source_id).and_return(nil)
      allow(HTTParty).to receive(:post)

      described_class.new(conversation: conversation).perform

      expect(HTTParty).not_to have_received(:post)
    end

    it 'is a no-op when the channel is not a Channel::Instagram' do
      allow(inbox).to receive(:channel_type).and_return('Channel::FacebookPage')
      allow(HTTParty).to receive(:post)

      described_class.new(conversation: conversation).perform

      expect(HTTParty).not_to have_received(:post)
    end

    it 'logs a warning and does not raise when the API returns an error' do
      error_response = instance_double(
        HTTParty::Response,
        success?: false,
        parsed_response: { 'error' => { 'code' => 190, 'message' => 'token expired' } }
      )
      allow(HTTParty).to receive(:post).and_return(error_response)

      expect(Rails.logger).to receive(:warn).with(
        a_string_matching(/\[Instagram MarkAsRead\] Failed to send mark_seen for conversation 99: 190 - token expired/)
      )
      expect { described_class.new(conversation: conversation).perform }.not_to raise_error
    end

    it 'logs a warning and does not raise when HTTParty raises' do
      allow(HTTParty).to receive(:post).and_raise(StandardError.new('network down'))

      expect(Rails.logger).to receive(:warn).with(
        a_string_matching(/\[Instagram MarkAsRead\] Failed to send mark_seen for conversation 99: network down/)
      )
      expect { described_class.new(conversation: conversation).perform }.not_to raise_error
    end
  end
end
