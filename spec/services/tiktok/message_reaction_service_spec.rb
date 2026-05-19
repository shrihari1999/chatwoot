# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tiktok::MessageReactionService do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_tiktok, account: account, business_id: 'biz-123') }
  let(:inbox) { channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: 'tt-conv-1') }
  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
                          additional_attributes: { 'conversation_id' => 'tt-conv-1' })
  end
  let!(:target_message) do
    create(:message, account: account, inbox: inbox, conversation: conversation,
                     source_id: 'tt-msg-1', content: 'Hello', message_type: :outgoing)
  end

  def build_content(reaction_items)
    {
      type: 'reaction',
      conversation_id: 'tt-conv-1',
      reaction: reaction_items
    }.deep_symbolize_keys
  end

  describe '#perform' do
    it 'applies an ADD EMOJI reaction with unique_identifier as sender_id' do
      content = build_content([{
                                operation: 'ADD', type: 'EMOJI', emoji: '❤️',
                                unique_identifier: 'user-1', original_msg_id: 'tt-msg-1'
                              }])

      described_class.new(channel: channel, content: content).perform

      expect(target_message.reload.content_attributes['reactions']).to eq('❤️' => ['user-1'])
    end

    it 'applies a REMOVE EMOJI reaction by clearing the sender from that emoji bucket' do
      target_message.update!(content_attributes: target_message.content_attributes.merge(reactions: { '❤️' => %w[user-1 user-2] }))

      content = build_content([{
                                operation: 'REMOVE', type: 'EMOJI', emoji: '❤️',
                                unique_identifier: 'user-1', original_msg_id: 'tt-msg-1'
                              }])

      described_class.new(channel: channel, content: content).perform

      expect(target_message.reload.content_attributes['reactions']).to eq('❤️' => ['user-2'])
    end

    it 'skips AI_EMOJI reactions without raising' do
      content = build_content([{
                                operation: 'ADD', type: 'AI_EMOJI', ai_emoji_url: 'https://example.com/ai.png',
                                unique_identifier: 'user-1', original_msg_id: 'tt-msg-1'
                              }])

      expect(Rails.logger).to receive(:info).with(/\[Tiktok Reaction\] Skipping non-EMOJI reaction type=AI_EMOJI/)
      expect { described_class.new(channel: channel, content: content).perform }.not_to(change { target_message.reload.content_attributes })
    end

    it 'skips when original_msg_id belongs to a different conversation' do
      other_contact_inbox = create(:contact_inbox, inbox: inbox, contact: contact, source_id: 'tt-conv-2')
      other_conversation = create(:conversation, account: account, inbox: inbox, contact: contact,
                                                 contact_inbox: other_contact_inbox,
                                                 additional_attributes: { 'conversation_id' => 'tt-conv-2' })
      create(:message, account: account, inbox: inbox, conversation: other_conversation,
                       source_id: 'tt-msg-other', message_type: :outgoing)

      content = build_content([{
                                operation: 'ADD', type: 'EMOJI', emoji: '👍',
                                unique_identifier: 'user-1', original_msg_id: 'tt-msg-other'
                              }])

      expect { described_class.new(channel: channel, content: content).perform }.not_to(change { target_message.reload.content_attributes })
    end

    it 'processes multiple reactions in a single webhook payload' do
      second_message = create(:message, account: account, inbox: inbox, conversation: conversation,
                                        source_id: 'tt-msg-2', message_type: :outgoing)

      content = build_content([
                                { operation: 'ADD', type: 'EMOJI', emoji: '❤️', unique_identifier: 'user-1', original_msg_id: 'tt-msg-1' },
                                { operation: 'ADD', type: 'EMOJI', emoji: '👍', unique_identifier: 'user-2', original_msg_id: 'tt-msg-2' }
                              ])

      described_class.new(channel: channel, content: content).perform

      expect(target_message.reload.content_attributes['reactions']).to eq('❤️' => ['user-1'])
      expect(second_message.reload.content_attributes['reactions']).to eq('👍' => ['user-2'])
    end
  end
end
