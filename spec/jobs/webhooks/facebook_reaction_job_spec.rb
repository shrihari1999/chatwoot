# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webhooks::FacebookReactionJob, type: :job do
  describe '#perform' do
    let(:page) { create(:channel_facebook_page) }
    let(:messaging) do
      {
        recipient: { id: page.page_id },
        sender: { id: '12345' },
        reaction: { mid: 'mid.123', emoji: '❤️', action: 'react', reaction: 'love' }
      }
    end

    before do
      # Required because the channel_facebook_page factory triggers a Graph API
      # subscribe POST via after_create_commit; WebMock's NetConnectNotAllowedError
      # is not a StandardError so it bypasses the rescue in Channel::FacebookPage#subscribe.
      stub_request(:post, /graph.facebook.com/).to_return(status: 200, body: '', headers: {})
    end

    # The gem's Common#to_json wraps the raw messaging hash under a 'messaging' key,
    # so the job receives {"messaging": {...}} in production.
    it 'calls MessageReactionService for matching page when payload is wrapped under messaging' do
      service = instance_double(Facebook::MessageReactionService)
      allow(Facebook::MessageReactionService).to receive(:new).and_return(service)
      allow(service).to receive(:perform)

      described_class.perform_now({ messaging: messaging }.to_json)

      expect(Facebook::MessageReactionService).to have_received(:new).with(
        inbox: page.inbox,
        messaging: messaging
      )
      expect(service).to have_received(:perform)
    end

    # Also support the unwrapped shape for robustness/back-compat.
    it 'calls MessageReactionService for matching page when payload is unwrapped' do
      service = instance_double(Facebook::MessageReactionService)
      allow(Facebook::MessageReactionService).to receive(:new).and_return(service)
      allow(service).to receive(:perform)

      described_class.perform_now(messaging.to_json)

      expect(Facebook::MessageReactionService).to have_received(:new).with(
        inbox: page.inbox,
        messaging: messaging
      )
      expect(service).to have_received(:perform)
    end

    it 'does nothing when no matching page exists' do
      allow(Facebook::MessageReactionService).to receive(:new)
      described_class.perform_now({ recipient: { id: 'unknown_page' } }.to_json)
      expect(Facebook::MessageReactionService).not_to have_received(:new)
    end

    it 'does nothing when page_id is blank' do
      allow(Facebook::MessageReactionService).to receive(:new)
      described_class.perform_now({ messaging: { sender: { id: '12345' } } }.to_json)
      expect(Facebook::MessageReactionService).not_to have_received(:new)
    end
  end
end
