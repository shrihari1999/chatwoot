# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webhooks::FacebookMessageEditJob do
  describe '#perform' do
    let(:account) { create(:account) }
    let(:facebook_channel) { create(:channel_facebook_page, account: account) }
    let(:inbox) { facebook_channel.inbox }
    let(:mid) { 'm_KXGKDUpO6xbVdAmZFBVpzU1AhKVJdAIUnUH4cwkvb' }

    before do
      # Required because the channel_facebook_page factory triggers a Graph API
      # subscribe POST via after_create_commit; WebMock's NetConnectNotAllowedError
      # is not a StandardError so it bypasses the rescue in Channel::FacebookPage#subscribe.
      stub_request(:post, /graph.facebook.com/).to_return(status: 200, body: '', headers: {})
    end

    # Use the wrapped shape that the gem actually enqueues (Common#to_json wraps
    # the raw messaging hash under a 'messaging' key).
    let(:message_edit_json) do
      {
        'messaging' => {
          'sender' => { 'id' => 'FB_USER_PSID' },
          'recipient' => { 'id' => facebook_channel.page_id },
          'timestamp' => 1_458_668_856_463,
          'message_edit' => { 'mid' => mid, 'text' => 'edited text' }
        }
      }.to_json
    end

    it 'calls Facebook::UpdateMessageService for matching page inboxes' do
      update_service = instance_double(Facebook::UpdateMessageService)
      allow(Facebook::UpdateMessageService).to receive(:new).and_return(update_service)
      allow(update_service).to receive(:perform)

      described_class.new.perform(message_edit_json)

      expect(Facebook::UpdateMessageService).to have_received(:new).with(
        inbox: inbox,
        response: an_instance_of(Integrations::Facebook::MessageEditParser)
      )
      expect(update_service).to have_received(:perform)
    end
  end
end
