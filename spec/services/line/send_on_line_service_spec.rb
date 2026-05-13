require 'rails_helper'

describe Line::SendOnLineService do
  describe '#perform' do
    let(:line_client) { double }
    let(:line_channel) { create(:channel_line) }
    let(:message) do
      create(:message, message_type: :outgoing, content: 'test',
                       conversation: create(:conversation, inbox: line_channel.inbox))
    end

    before do
      allow(Line::Bot::Client).to receive(:new).and_return(line_client)
    end

    context 'when message send' do
      it 'calls @channel.client.push_message' do
        allow(line_client).to receive(:push_message)
        expect(line_client).to receive(:push_message)
        described_class.new(message: message).perform
      end
    end

    context 'when message send fails without details' do
      let(:error_response) do
        {
          'message' => 'The request was invalid'
        }.to_json
      end

      before do
        allow(line_client).to receive(:push_message).and_return(OpenStruct.new(code: '400', body: error_response))
      end

      it 'updates the message status to failed' do
        described_class.new(message: message).perform
        message.reload
        expect(message.status).to eq('failed')
      end

      it 'updates the external error without details' do
        described_class.new(message: message).perform
        message.reload
        expect(message.external_error).to eq('The request was invalid')
      end
    end

    context 'when message send fails with details' do
      let(:error_response) do
        {
          'message' => 'The request was invalid',
          'details' => [
            {
              'property' => 'messages[0].text',
              'message' => 'May not be empty'
            }
          ]
        }.to_json
      end

      before do
        allow(line_client).to receive(:push_message).and_return(OpenStruct.new(code: '400', body: error_response))
      end

      it 'updates the message status to failed' do
        described_class.new(message: message).perform
        message.reload
        expect(message.status).to eq('failed')
      end

      it 'updates the external error with details' do
        described_class.new(message: message).perform
        message.reload
        expect(message.external_error).to eq('The request was invalid, messages[0].text: May not be empty')
      end
    end

    context 'when message send succeeds' do
      let(:success_response) do
        {
          'message' => 'ok'
        }.to_json
      end

      before do
        allow(line_client).to receive(:push_message).and_return(OpenStruct.new(code: '200', body: success_response))
      end

      it 'updates the message status to delivered' do
        described_class.new(message: message).perform
        message.reload
        expect(message.status).to eq('delivered')
      end
    end

    context 'with message input_select' do
      let(:success_response) do
        {
          'message' => 'ok'
        }.to_json
      end

      let(:expect_message) do
        {
          type: 'flex',
          altText: 'test',
          contents: {
            type: 'bubble',
            body: {
              type: 'box',
              layout: 'vertical',
              contents: [
                {
                  type: 'text',
                  text: 'test',
                  wrap: true
                },
                {
                  type: 'button',
                  style: 'link',
                  height: 'sm',
                  action: {
                    type: 'message',
                    label: 'text 1',
                    text: 'value 1'
                  }
                },
                {
                  type: 'button',
                  style: 'link',
                  height: 'sm',
                  action: {
                    type: 'message',
                    label: 'text 2',
                    text: 'value 2'
                  }
                }
              ]
            }
          }
        }
      end

      it 'sends the message with input_select' do
        message = create(
          :message, message_type: :outgoing, content: 'test', content_type: 'input_select',
                    content_attributes: { 'items' => [{ 'title' => 'text 1', 'value' => 'value 1' }, { 'title' => 'text 2', 'value' => 'value 2' }] },
                    conversation: create(:conversation, inbox: line_channel.inbox)
        )

        expect(line_client).to receive(:push_message).with(
          message.conversation.contact_inbox.source_id,
          expect_message
        ).and_return(OpenStruct.new(code: '200', body: success_response))

        described_class.new(message: message).perform
      end
    end

    context 'with message attachments' do
      it 'sends the message with text and attachments' do
        attachment = message.attachments.new(account_id: message.account_id, file_type: :image)
        attachment.file.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: 'avatar.png', content_type: 'image/png')
        attachment.save!
        expected_original_url_regex = %r{rails/active_storage/blobs/redirect/[a-zA-Z0-9=_\-+]+/avatar\.png}
        expected_preview_url_regex = %r{rails/active_storage/representations/redirect/[a-zA-Z0-9=_\-+]+/[a-zA-Z0-9=_\-+]+/avatar\.png}

        expect(line_client).to receive(:push_message).with(
          message.conversation.contact_inbox.source_id,
          [
            { type: 'text', text: message.content },
            {
              type: 'image',
              originalContentUrl: match(expected_original_url_regex),
              previewImageUrl: match(expected_preview_url_regex)
            }
          ]
        )

        described_class.new(message: message).perform
      end

      it 'sends the message with attachments only' do
        attachment = message.attachments.new(account_id: message.account_id, file_type: :image)
        attachment.file.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: 'avatar.png', content_type: 'image/png')
        attachment.save!
        message.update!(content: nil)
        expected_original_url_regex = %r{rails/active_storage/blobs/redirect/[a-zA-Z0-9=_\-+]+/avatar\.png}
        expected_preview_url_regex = %r{rails/active_storage/representations/redirect/[a-zA-Z0-9=_\-+]+/[a-zA-Z0-9=_\-+]+/avatar\.png}

        expect(line_client).to receive(:push_message).with(
          message.conversation.contact_inbox.source_id,
          [
            {
              type: 'image',
              originalContentUrl: match(expected_original_url_regex),
              previewImageUrl: match(expected_preview_url_regex)
            }
          ]
        )

        described_class.new(message: message).perform
      end

      it 'sends the message with text only' do
        message.attachments.destroy_all
        expect(line_client).to receive(:push_message).with(
          message.conversation.contact_inbox.source_id,
          { type: 'text', text: message.content }
        )

        described_class.new(message: message).perform
      end

      it 'sends the message with text and audio attachment including duration' do
        attachment = message.attachments.new(account_id: message.account_id, file_type: :audio)
        attachment.file.attach(io: Rails.root.join('spec/assets/sample.mp3').open, filename: 'sample.mp3', content_type: 'audio/mpeg')
        attachment.save!
        allow_any_instance_of(ActiveStorage::Blob).to receive(:analyzed?).and_return(true)
        allow_any_instance_of(ActiveStorage::Blob).to receive(:metadata).and_return({ duration: 5.2 })
        expected_original_url_regex = %r{rails/active_storage/blobs/redirect/[a-zA-Z0-9=_\-+]+/sample\.mp3}

        expect(line_client).to receive(:push_message).with(
          message.conversation.contact_inbox.source_id,
          [
            { type: 'text', text: message.content },
            {
              type: 'audio',
              originalContentUrl: match(expected_original_url_regex),
              duration: 5200
            }
          ]
        )

        described_class.new(message: message).perform
      end

      it 'falls back to 1000ms when audio duration metadata is missing' do
        attachment = message.attachments.new(account_id: message.account_id, file_type: :audio)
        attachment.file.attach(io: Rails.root.join('spec/assets/sample.mp3').open, filename: 'sample.mp3', content_type: 'audio/mpeg')
        attachment.save!
        allow_any_instance_of(ActiveStorage::Blob).to receive(:analyzed?).and_return(true)
        allow_any_instance_of(ActiveStorage::Blob).to receive(:metadata).and_return({})

        expect(line_client).to receive(:push_message).with(
          message.conversation.contact_inbox.source_id,
          [
            { type: 'text', text: message.content },
            hash_including(type: 'audio', duration: 1000)
          ]
        )

        described_class.new(message: message).perform
      end
    end

    context 'when the agent replies to a quoted customer message' do
      let(:conversation) { create(:conversation, inbox: line_channel.inbox) }

      let(:quoted_message) do
        create(:message,
               message_type: :incoming,
               source_id: 'line-msg-111',
               additional_attributes: quoted_attributes,
               conversation: conversation)
      end

      let(:reply_message) do
        create(:message,
               message_type: :outgoing,
               content: 'reply',
               content_attributes: { 'in_reply_to_external_id' => quoted_message.source_id },
               conversation: conversation)
      end

      before do
        quoted_message # ensure the quoted message exists before the reply is built
        allow(line_client).to receive(:push_message).and_return(OpenStruct.new(code: '200', body: { 'message' => 'ok' }.to_json))
      end

      context 'with a quoteToken on the quoted message' do
        let(:quoted_attributes) { { 'quote_token' => 'qt_abc123' } }

        it 'includes quoteToken in the push payload' do
          expect(line_client).to receive(:push_message).with(
            reply_message.conversation.contact_inbox.source_id,
            { type: 'text', text: reply_message.content, quoteToken: 'qt_abc123' }
          )

          described_class.new(message: reply_message).perform
        end
      end

      context 'without a quoteToken (consumed or absent)' do
        let(:quoted_attributes) { {} }

        it 'sends the message without a quoteToken' do
          expect(line_client).to receive(:push_message).with(
            reply_message.conversation.contact_inbox.source_id,
            { type: 'text', text: reply_message.content }
          )

          described_class.new(message: reply_message).perform
        end
      end
    end

    context 'when the push_message response contains sentMessages metadata' do
      let(:outgoing_message) do
        create(:message, message_type: :outgoing, content: 'hello',
                         conversation: create(:conversation, inbox: line_channel.inbox))
      end

      it 'persists the LINE message id as source_id and stores the quoteToken' do
        sent_messages_response = {
          'sentMessages' => [
            { 'id' => '461230878437638435', 'quoteToken' => 'qt_new_from_response' }
          ]
        }.to_json
        allow(line_client).to receive(:push_message).and_return(OpenStruct.new(code: '200', body: sent_messages_response))

        described_class.new(message: outgoing_message).perform
        outgoing_message.reload

        expect(outgoing_message.source_id).to eq('461230878437638435')
        expect(outgoing_message.additional_attributes['quote_token']).to eq('qt_new_from_response')
      end

      it 'leaves the message untouched when sentMessages is absent' do
        allow(line_client).to receive(:push_message).and_return(OpenStruct.new(code: '200', body: { 'message' => 'ok' }.to_json))

        expect { described_class.new(message: outgoing_message).perform }
          .not_to(change { [outgoing_message.reload.source_id, outgoing_message.additional_attributes] })
      end

      it 'does not persist metadata on a failed send' do
        error_response = {
          'message' => 'The request was invalid',
          'sentMessages' => [{ 'id' => 'should-not-be-stored', 'quoteToken' => 'should-not-be-stored' }]
        }.to_json
        allow(line_client).to receive(:push_message).and_return(OpenStruct.new(code: '400', body: error_response))

        described_class.new(message: outgoing_message).perform
        outgoing_message.reload

        expect(outgoing_message.source_id).to be_nil
        expect(outgoing_message.additional_attributes).not_to have_key('quote_token')
      end
    end
  end
end
