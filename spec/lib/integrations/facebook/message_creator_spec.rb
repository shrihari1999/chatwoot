# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Integrations::Facebook::MessageCreator do
  before do
    allow(Facebook::Messenger::Subscriptions).to receive(:subscribe).and_return(true)
  end

  let(:account) { create(:account) }
  let(:facebook_channel) { create(:channel_facebook_page, account: account, page_id: 'PAGE_ID') }
  let(:inbox) { facebook_channel.inbox }
  let(:response) { instance_double(Integrations::Facebook::MessageParser) }

  describe '#perform' do
    context 'when response is a delete event' do
      let(:delete_service) { instance_double(Facebook::IncomingDeleteService, perform: true) }

      before do
        allow(response).to receive_messages(deleted?: true, recipient_id: 'PAGE_ID')
      end

      it 'invokes Facebook::IncomingDeleteService for each matching inbox' do
        # Ensure inbox is created before lookup
        inbox

        expect(Facebook::IncomingDeleteService).to receive(:new)
          .with(inbox: inbox, response: response).and_return(delete_service)
        expect(delete_service).to receive(:perform)
        expect(Messages::Facebook::MessageBuilder).not_to receive(:new)

        described_class.new(response).perform
      end
    end
  end
end
