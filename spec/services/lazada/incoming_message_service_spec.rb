# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lazada::IncomingMessageService do
  let(:account) { create(:account) }
  let(:lazada_channel) { create(:channel_lazada, account: account) }
  let(:inbox) { lazada_channel.inbox }

  describe '#perform' do
    it 'returns when data is blank' do
      expect(Lazada::IncomingRecallService).not_to receive(:new)
      described_class.new(inbox: inbox, params: { data: nil }).perform
    end

    it 'dispatches to IncomingRecallService when status=1, regardless of sender' do
      params = { data: { status: 1, message_id: 'm1', from_account_type: 1 } }
      service_double = instance_double(Lazada::IncomingRecallService, perform: nil)
      expect(Lazada::IncomingRecallService).to receive(:new).with(inbox: inbox, params: params).and_return(service_double)

      described_class.new(inbox: inbox, params: params).perform
    end

    it 'dispatches recalls from sellers to IncomingRecallService too' do
      # from_account_type=2 (seller) was previously short-circuited before the
      # recall check. This test locks in the new behaviour.
      params = { data: { status: 1, message_id: 'm2', from_account_type: 2 } }
      service_double = instance_double(Lazada::IncomingRecallService, perform: nil)
      expect(Lazada::IncomingRecallService).to receive(:new).with(inbox: inbox, params: params).and_return(service_double)

      described_class.new(inbox: inbox, params: params).perform
    end

    it 'ignores non-recall seller messages (status != 1, from_account_type=2)' do
      params = { data: { status: 0, message_id: 'm3', from_account_type: 2 } }
      expect(Lazada::IncomingRecallService).not_to receive(:new)

      described_class.new(inbox: inbox, params: params).perform
    end

    it 'treats string "1" status as a recall (Lazada sometimes sends status as a string)' do
      params = { data: { status: '1', message_id: 'm4', from_account_type: 1 } }
      service_double = instance_double(Lazada::IncomingRecallService, perform: nil)
      expect(Lazada::IncomingRecallService).to receive(:new).with(inbox: inbox, params: params).and_return(service_double)

      described_class.new(inbox: inbox, params: params).perform
    end

    it 'does not treat status=2 as a recall' do
      params = { data: { status: 2, message_id: 'm5', from_account_type: 2 } }
      # from_account_type=2 (seller) ensures we short-circuit after the recall
      # check without needing to stub the full message creation path.
      expect(Lazada::IncomingRecallService).not_to receive(:new)

      described_class.new(inbox: inbox, params: params).perform
    end
  end

  describe 'contact profile enrichment' do
    let(:params) do
      {
        data: {
          template_id: 1, from_account_type: 1, from_user_id: 'u1', message_id: 'm20',
          session_id: 'sess-1', content: { txt: 'hi' }.to_json
        }
      }
    end

    it 'enqueues an avatar fetch for an incoming buyer message with a session_id' do
      expect(Lazada::ContactProfileJob).to receive(:perform_later).with(
        channel_id: lazada_channel.id, contact_id: kind_of(Integer), session_id: 'sess-1'
      )

      described_class.new(inbox: inbox, params: params).perform
    end

    it 'does not enqueue when the session_id is missing' do
      params[:data].delete(:session_id)
      expect(Lazada::ContactProfileJob).not_to receive(:perform_later)

      described_class.new(inbox: inbox, params: params).perform
    end
  end

  describe 'image attachment' do
    let(:img_url) { 'https://lazada-cdn.local/sample.png' }
    let(:params) do
      {
        data: {
          template_id: 3, from_account_type: 1, from_user_id: 'u1', message_id: 'm10',
          content: { imgUrl: img_url }.to_json
        }
      }
    end

    it 'downloads the image bytes into storage instead of persisting the remote url' do
      stub_request(:get, img_url)
        .to_return(status: 200, body: 'imagedata', headers: { 'Content-Type' => 'image/png' })

      described_class.new(inbox: inbox, params: params).perform

      attachment = inbox.conversations.last.messages.last.attachments.last
      expect(attachment.file_type).to eq('image')
      expect(attachment.file.attached?).to be(true)
      expect(attachment.external_url).to be_nil
    end

    it 'falls back to external_url when the download fails' do
      stub_request(:get, img_url).to_raise(Down::Error.new('boom'))

      described_class.new(inbox: inbox, params: params).perform

      attachment = inbox.conversations.last.messages.last.attachments.last
      expect(attachment.file_type).to eq('image')
      expect(attachment.external_url).to eq(img_url)
    end
  end
end
