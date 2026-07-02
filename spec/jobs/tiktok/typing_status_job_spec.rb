# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tiktok::TypingStatusJob do
  let(:conversation) { create(:conversation) }

  describe '#perform' do
    it 'calls Tiktok::TypingStatusService#perform' do
      service = instance_double(Tiktok::TypingStatusService)
      allow(Tiktok::TypingStatusService).to receive(:new)
        .with(conversation: conversation, typing_status: 'on').and_return(service)
      expect(service).to receive(:perform)
      described_class.new.perform(conversation, 'on')
    end
  end
end
