# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Line::MarkAsReadJob do
  let(:conversation) { create(:conversation) }

  describe '#perform' do
    it 'calls Line::MarkAsReadService#perform' do
      service = instance_double(Line::MarkAsReadService)
      allow(Line::MarkAsReadService).to receive(:new).with(conversation: conversation).and_return(service)
      expect(service).to receive(:perform)
      described_class.new.perform(conversation)
    end
  end
end
