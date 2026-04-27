# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facebook::MarkAsReadJob do
  let(:conversation) { create(:conversation) }

  describe '#perform' do
    it 'delegates to Facebook::MarkAsReadService' do
      service = instance_double(Facebook::MarkAsReadService)
      allow(Facebook::MarkAsReadService).to receive(:new).with(conversation: conversation).and_return(service)
      allow(service).to receive(:perform)

      described_class.new.perform(conversation)

      expect(service).to have_received(:perform)
    end
  end
end
