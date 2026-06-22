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

  it 'marks the message FAILED-unsupported for a non-sendable attachment (e.g. audio)' do
    message.attachments.create!(
      account_id: account.id, file_type: :audio,
      file: { io: Rails.root.join('spec/assets/sample.mp3').open, filename: 'a.mp3', content_type: 'audio/mpeg' }
    )
    expect(client).not_to receive(:upload_image)
    expect(Tiktok::Shop::VideoUploadService).not_to receive(:new)

    described_class.new(message: message).perform

    expect(message.reload.status).to eq('failed')
  end

  it 'uploads a video attachment and sends it as a VIDEO message with the returned vid' do
    message.update!(content: nil)
    message.attachments.create!(
      account_id: account.id, file_type: :video,
      file: { io: Rails.root.join('spec/assets/sample.mov').open, filename: 'v.mov', content_type: 'video/quicktime' }
    )
    uploader = instance_double(Tiktok::Shop::VideoUploadService, perform: 'vid-xyz')
    allow(Tiktok::Shop::VideoUploadService).to receive(:new).and_return(uploader)
    expect(client).to receive(:send_message)
      .with('tts-conv-1', type: 'VIDEO', content_payload: { vid: 'vid-xyz' })
      .and_return(OpenStruct.new(success?: true, body: { 'data' => { 'message_id' => 'm-v' } }))

    described_class.new(message: message).perform

    expect(message.reload.status).to eq('delivered')
  end

  it 'marks the message FAILED when the video upload returns no vid' do
    message.update!(content: nil)
    message.attachments.create!(
      account_id: account.id, file_type: :video,
      file: { io: Rails.root.join('spec/assets/sample.mov').open, filename: 'v.mov', content_type: 'video/quicktime' }
    )
    uploader = instance_double(Tiktok::Shop::VideoUploadService, perform: nil)
    allow(Tiktok::Shop::VideoUploadService).to receive(:new).and_return(uploader)
    expect(client).not_to receive(:send_message)

    described_class.new(message: message).perform

    expect(message.reload.status).to eq('failed')
  end
end
