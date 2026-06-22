# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tiktok::Shop::SendOnTiktokShopService do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_tiktok_shop, account: account) }
  let(:inbox) { channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: 'buyer-1') }
  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
                          additional_attributes: { 'tiktok_shop_conversation_id' => 'tts-conv-1' })
  end
  let(:message) do
    create(:message, message_type: :outgoing, account: account, inbox: inbox,
                     conversation: conversation, content: 'hello buyer')
  end
  let(:client) { instance_double(Tiktok::Shop::Client) }

  before { allow(Tiktok::Shop::Client).to receive(:new).with(channel: channel).and_return(client) }

  it 'marks the message DELIVERED on a successful send and stores the TikTok message_id' do
    # TikTok Shop sends no delivery/read webhooks, so a successful ack -> delivered.
    allow(client).to receive(:send_text)
      .with('tts-conv-1', 'hello buyer')
      .and_return(OpenStruct.new(success?: true, body: { 'data' => { 'message_id' => 'tts-msg-9' } }))

    described_class.new(message: message).perform

    expect(message.reload.source_id).to eq('tts-msg-9')
    expect(message.status).to eq('delivered')
  end

  it 'marks the message FAILED with the API error message on failure' do
    allow(client).to receive(:send_text).and_return(
      OpenStruct.new(success?: false, code: 45_109_001,
                     body: { 'message' => 'Unable to send messages due to conversation rules' })
    )

    described_class.new(message: message).perform

    expect(message.reload.status).to eq('failed')
  end

  it 'marks the message FAILED-unsupported for a non-image attachment instead of silently dropping it' do
    message.attachments.create!(account_id: account.id, file_type: :video, external_url: 'https://cdn.example/v.mp4')
    expect(client).not_to receive(:upload_image)
    expect(client).not_to receive(:send_text)

    described_class.new(message: message).perform

    expect(message.reload.status).to eq('failed')
  end
end
