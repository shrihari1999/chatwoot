# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lazada::MarkAsReadJob do
  let(:conversation) { create(:conversation) }

  describe '#perform' do
    it 'calls Lazada::MarkAsReadService#perform' do
      service = instance_double(Lazada::MarkAsReadService)
      allow(Lazada::MarkAsReadService).to receive(:new).with(conversation: conversation).and_return(service)
      expect(service).to receive(:perform)
      described_class.new.perform(conversation)
    end
  end
end
