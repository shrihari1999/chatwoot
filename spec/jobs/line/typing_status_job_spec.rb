# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Line::TypingStatusJob do
  let(:conversation) { create(:conversation) }

  describe '#perform' do
    it 'calls Line::TypingStatusService#perform' do
      service = instance_double(Line::TypingStatusService)
      allow(Line::TypingStatusService).to receive(:new)
        .with(conversation: conversation, typing_status: 'on').and_return(service)
      expect(service).to receive(:perform)
      described_class.new.perform(conversation, 'on')
    end
  end
end
