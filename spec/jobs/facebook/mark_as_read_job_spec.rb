# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facebook::MarkAsReadJob do
  let(:conversation) { create(:conversation) }

  describe '#perform' do
    it 'calls Facebook::MarkAsReadService#perform' do
      service = instance_double(Facebook::MarkAsReadService)
      allow(Facebook::MarkAsReadService).to receive(:new).with(conversation: conversation).and_return(service)
      expect(service).to receive(:perform)
      described_class.new.perform(conversation)
    end
  end
end
