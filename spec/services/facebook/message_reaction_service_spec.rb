# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facebook::MessageReactionService do
  let(:inbox)   { create(:inbox) }
  let(:message) { create(:message, source_id: 'mid.123', inbox: inbox) }

  let(:react_messaging) do
    {
      sender: { id: '12345' },
      reaction: { mid: 'mid.123', emoji: '❤️', action: 'react' }
    }
  end

  let(:unreact_messaging) do
    {
      sender: { id: '12345' },
      reaction: { mid: 'mid.123', emoji: '❤️', action: 'unreact' }
    }
  end

  describe '#perform' do
    it 'calls apply_reaction! with react action' do
      allow(inbox.messages).to receive(:find_by).with(source_id: 'mid.123').and_return(message)
      allow(message).to receive(:apply_reaction!)

      described_class.new(inbox: inbox, messaging: react_messaging).perform

      expect(message).to have_received(:apply_reaction!).with(
        emoji: '❤️', sender_id: '12345', action: 'react'
      )
    end

    it 'calls apply_reaction! with unreact action' do
      allow(inbox.messages).to receive(:find_by).with(source_id: 'mid.123').and_return(message)
      allow(message).to receive(:apply_reaction!)

      described_class.new(inbox: inbox, messaging: unreact_messaging).perform

      expect(message).to have_received(:apply_reaction!).with(
        emoji: '❤️', sender_id: '12345', action: 'unreact'
      )
    end

    it 'is a no-op when message is not found' do
      allow(inbox.messages).to receive(:find_by).and_return(nil)

      expect do
        described_class.new(inbox: inbox, messaging: react_messaging).perform
      end.not_to raise_error
    end
  end
end
