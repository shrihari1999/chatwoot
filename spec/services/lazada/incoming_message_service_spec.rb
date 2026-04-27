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
end
