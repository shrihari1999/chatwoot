# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Instagram::ReactionService do
  let(:inbox)   { create(:inbox) }
  let(:channel) { instance_double('Channel::Instagram', inbox: inbox) }
  let(:message) { create(:message, source_id: 'mid.456', inbox: inbox) }

  let(:react_params) do
    {
      sender: { id: 'igsid_abc' },
      reaction: { mid: 'mid.456', emoji: '😂', action: 'react' }
    }
  end

  let(:unreact_params) do
    {
      sender: { id: 'igsid_abc' },
      reaction: { mid: 'mid.456', emoji: '😂', action: 'unreact' }
    }
  end

  describe '#perform' do
    it 'calls apply_reaction! with react action' do
      allow(inbox.messages).to receive(:find_by).with(source_id: 'mid.456').and_return(message)
      allow(message).to receive(:apply_reaction!)

      described_class.new(params: react_params, channel: channel).perform

      expect(message).to have_received(:apply_reaction!).with(
        emoji: '😂', sender_id: 'igsid_abc', action: 'react'
      )
    end

    it 'calls apply_reaction! with unreact action' do
      allow(inbox.messages).to receive(:find_by).with(source_id: 'mid.456').and_return(message)
      allow(message).to receive(:apply_reaction!)

      described_class.new(params: unreact_params, channel: channel).perform

      expect(message).to have_received(:apply_reaction!).with(
        emoji: '😂', sender_id: 'igsid_abc', action: 'unreact'
      )
    end

    it 'is a no-op when message is not found' do
      allow(inbox.messages).to receive(:find_by).and_return(nil)

      expect do
        described_class.new(params: react_params, channel: channel).perform
      end.not_to raise_error
    end
  end
end
