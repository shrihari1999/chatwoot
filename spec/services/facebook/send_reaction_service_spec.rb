# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facebook::SendReactionService do
  let(:account)      { instance_double(Account) }
  let(:channel)      { instance_double(Channel::FacebookPage, page_id: 'page_123') }
  let(:inbox)        { instance_double(Inbox, channel: channel, id: 1) }
  let(:contact)      { instance_double(Contact) }
  let(:conversation) { instance_double(Conversation, inbox: inbox, inbox_id: 1, contact: contact) }
  let(:message)      { instance_double(Message, conversation: conversation, source_id: 'mid.abc', id: 42, account: account) }

  before do
    allow(contact).to receive(:get_source_id).with(1).and_return('psid_xyz')
  end

  describe '#perform' do
    it 'delivers react action via Bot.deliver' do
      allow(Facebook::Messenger::Bot).to receive(:deliver)

      described_class.new(message: message, emoji: '❤️', action: 'react').perform

      expect(Facebook::Messenger::Bot).to have_received(:deliver).with(
        {
          recipient: { id: 'psid_xyz' },
          sender_action: 'react',
          payload: { message_id: 'mid.abc', reaction: '❤️' }
        },
        page_id: 'page_123'
      )
    end

    it 'delivers unreact action without reaction key' do
      allow(Facebook::Messenger::Bot).to receive(:deliver)

      described_class.new(message: message, emoji: '❤️', action: 'unreact').perform

      expect(Facebook::Messenger::Bot).to have_received(:deliver).with(
        {
          recipient: { id: 'psid_xyz' },
          sender_action: 'unreact',
          payload: { message_id: 'mid.abc' }
        },
        page_id: 'page_123'
      )
    end

    it 'is a no-op when psid is blank' do
      allow(contact).to receive(:get_source_id).and_return(nil)
      allow(Facebook::Messenger::Bot).to receive(:deliver)

      described_class.new(message: message, emoji: '❤️', action: 'react').perform

      expect(Facebook::Messenger::Bot).not_to have_received(:deliver)
    end

    it 'is a no-op when mid is blank' do
      allow(message).to receive(:source_id).and_return(nil)
      allow(Facebook::Messenger::Bot).to receive(:deliver)

      described_class.new(message: message, emoji: '❤️', action: 'react').perform

      expect(Facebook::Messenger::Bot).not_to have_received(:deliver)
    end

    it 'tracks the exception and re-raises on FacebookError so the controller can surface failure' do
      tracker = instance_double(ChatwootExceptionTracker, capture_exception: true)
      allow(ChatwootExceptionTracker).to receive(:new).and_return(tracker)
      allow(Facebook::Messenger::Bot).to receive(:deliver).and_raise(Facebook::Messenger::FacebookError.new('error' => { 'message' => 'boom' }))

      expect do
        described_class.new(message: message, emoji: '❤️', action: 'react').perform
      end.to raise_error(Facebook::Messenger::FacebookError)

      expect(tracker).to have_received(:capture_exception)
    end
  end
end
