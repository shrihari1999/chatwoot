require 'rails_helper'

describe MessageTemplates::Template::OutOfOffice do
  context 'when this hook is called' do
    let(:conversation) { create(:conversation) }

    it 'creates the out of office messages' do
      described_class.new(conversation: conversation).perform
      expect(conversation.messages.template.count).to eq(1)
      expect(conversation.messages.template.first.content).to eq(conversation.inbox.out_of_office_message)
    end

    it 'creates the out of office messages with template variable' do
      conversation.inbox.update!(out_of_office_message: 'Hey, {{contact.name}} we are unavailable at the moment.')
      described_class.new(conversation: conversation).perform
      expect(conversation.messages.count).to eq(1)
      expect(conversation.messages.last.content).to eq("Hey, #{conversation.contact.name} we are unavailable at the moment.")
    end

    it 'creates the out of office messages with more than one variable strings' do
      conversation.inbox.update!(out_of_office_message:
        'Hey, {{contact.name}} we are unavailable at the moment. - from {{account.name}}')
      described_class.new(conversation: conversation).perform
      expect(conversation.messages.count).to eq(1)
      expect(conversation.messages.last.content).to eq(
        "Hey, #{conversation.contact.name} we are unavailable at the moment. - from #{conversation.account.name}"
      )
    end
  end

  context 'when the inbox rotates through out of office variants' do
    let(:inbox) { create(:inbox, channel: create(:channel_instagram), out_of_office_message: 'closed one') }
    let(:conversation) { create(:conversation, inbox: inbox, account: inbox.account) }

    before do
      inbox.update!(out_of_office_message_variants: ['closed two', 'closed three'])
    end

    it 'sends a different variant on each successive send' do
      3.times { described_class.new(conversation: conversation).perform }

      expect(conversation.messages.template.order(:id).pluck(:content)).to eq(['closed one', 'closed two', 'closed three'])
    end

    it 'wraps back to the first variant after the last one' do
      4.times { described_class.new(conversation: conversation).perform }

      expect(conversation.messages.template.order(:id).last.content).to eq('closed one')
    end

    it 'still sends when the first wording is empty and only a later variant is filled in' do
      inbox.update!(out_of_office_message: nil, out_of_office_message_variants: ['', 'closed three'])
      allow(conversation.inbox).to receive(:out_of_office?).and_return(true)

      described_class.perform_if_applicable(conversation)

      expect(conversation.messages.template.last.content).to eq('closed three')
    end

    it 'substitutes variables in whichever variant is drawn' do
      inbox.update!(out_of_office_message_variants: ['Hey {{contact.name}}, we are closed.'])
      described_class.new(conversation: conversation).perform
      described_class.new(conversation: conversation).perform

      expect(conversation.messages.template.order(:id).last.content).to eq("Hey #{conversation.contact.name}, we are closed.")
    end
  end

  context 'when the inbox is not an instagram inbox' do
    let(:inbox) { create(:inbox, channel: create(:channel_line), out_of_office_message: 'closed one') }
    let(:conversation) { create(:conversation, inbox: inbox, account: inbox.account) }

    it 'keeps sending the single out of office message even if variants are set' do
      inbox.update!(out_of_office_message_variants: ['closed two', 'closed three'])

      3.times { described_class.new(conversation: conversation).perform }

      expect(conversation.messages.template.pluck(:content)).to all(eq('closed one'))
    end
  end
end
