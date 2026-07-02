# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Conversations::ChannelTypingRelay do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, channel: channel) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  def relay(typing_status: 'on', is_private: false)
    described_class.new(conversation: conversation, typing_status: typing_status, is_private: is_private).perform
  end

  before do
    allow(Facebook::Messenger::Subscriptions).to receive(:subscribe).and_return(true)
    allow(Facebook::TypingStatusJob).to receive(:perform_later)
    allow(Instagram::TypingStatusJob).to receive(:perform_later)
    allow(Line::TypingStatusJob).to receive(:perform_later)
    allow(Tiktok::TypingStatusJob).to receive(:perform_later)
  end

  context 'when the note is private' do
    let(:channel) { create(:channel_facebook_page, account: account) }

    it 'never enqueues a typing job' do
      relay(typing_status: 'on', is_private: true)
      expect(Facebook::TypingStatusJob).not_to have_received(:perform_later)
    end

    it 'treats a truthy string is_private as private' do
      relay(typing_status: 'on', is_private: 'true')
      expect(Facebook::TypingStatusJob).not_to have_received(:perform_later)
    end
  end

  context 'when the inbox is a Facebook page' do
    let(:channel) { create(:channel_facebook_page, account: account) }

    it 'enqueues the Facebook job on typing on' do
      relay(typing_status: 'on')
      expect(Facebook::TypingStatusJob).to have_received(:perform_later).with(conversation, 'on')
    end

    it 'enqueues the Facebook job on typing off (Messenger supports typing_off)' do
      relay(typing_status: 'off')
      expect(Facebook::TypingStatusJob).to have_received(:perform_later).with(conversation, 'off')
    end

    context 'when the conversation is an Instagram DM on the Facebook page channel' do
      before { conversation.update!(additional_attributes: { 'type' => 'instagram_direct_message' }) }

      it 'does not enqueue the Facebook job' do
        relay(typing_status: 'on')
        expect(Facebook::TypingStatusJob).not_to have_received(:perform_later)
      end
    end
  end

  context 'when the inbox is a dedicated Instagram channel' do
    let(:channel) { create(:channel_instagram, account: account) }

    it 'enqueues the Instagram job on both on and off' do
      relay(typing_status: 'on')
      relay(typing_status: 'off')
      expect(Instagram::TypingStatusJob).to have_received(:perform_later).with(conversation, 'on')
      expect(Instagram::TypingStatusJob).to have_received(:perform_later).with(conversation, 'off')
    end
  end

  context 'when the inbox is a LINE channel (start-only)' do
    let(:channel) { create(:channel_line, account: account) }

    it 'enqueues the LINE job on typing on' do
      relay(typing_status: 'on')
      expect(Line::TypingStatusJob).to have_received(:perform_later).with(conversation, 'on')
    end

    it 'does not enqueue on typing off (LINE has no stop)' do
      relay(typing_status: 'off')
      expect(Line::TypingStatusJob).not_to have_received(:perform_later)
    end
  end

  context 'when the inbox is a TikTok channel (start-only)' do
    let(:channel) { create(:channel_tiktok, account: account) }

    it 'enqueues the TikTok job on typing on' do
      relay(typing_status: 'on')
      expect(Tiktok::TypingStatusJob).to have_received(:perform_later).with(conversation, 'on')
    end

    it 'does not enqueue on typing off (TikTok has no stop)' do
      relay(typing_status: 'off')
      expect(Tiktok::TypingStatusJob).not_to have_received(:perform_later)
    end
  end

  context 'when the inbox is a channel without a typing indicator' do
    let(:channel) { create(:channel_widget, account: account) }

    it 'enqueues nothing' do
      relay(typing_status: 'on')
      expect(Facebook::TypingStatusJob).not_to have_received(:perform_later)
      expect(Instagram::TypingStatusJob).not_to have_received(:perform_later)
      expect(Line::TypingStatusJob).not_to have_received(:perform_later)
      expect(Tiktok::TypingStatusJob).not_to have_received(:perform_later)
    end
  end
end
