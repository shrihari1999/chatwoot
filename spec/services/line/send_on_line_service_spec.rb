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

      context 'when the agent replies to a customer message that has a quoteToken' do
        let(:quoted_message) do
          create(:message,
                 message_type: :incoming,
                 source_id: 'line-msg-111',
                 additional_attributes: { 'quote_token' => 'qt_abc123' },
                 conversation: message.conversation)
        end

        let(:reply_message) do
          create(:message,
                 message_type: :outgoing,
                 content: 'quoting you',
                 content_attributes: { 'in_reply_to_external_id' => quoted_message.source_id },
                 conversation: message.conversation)
        end

        before do
          quoted_message # ensure it is persisted before the reply is sent
          allow(line_client).to receive(:push_message).and_return(OpenStruct.new(code: '200', body: { 'message' => 'ok' }.to_json))
        end

        it 'includes quoteToken in the push payload' do
          expect(line_client).to receive(:push_message).with(
            reply_message.conversation.contact_inbox.source_id,
            { type: 'text', text: reply_message.content, quoteToken: 'qt_abc123' }
          )

          described_class.new(message: reply_message).perform
        end
      end

      context 'when the agent replies to a message whose quoteToken has been consumed or is absent' do
        let(:quoted_message) do
          create(:message,
                 message_type: :incoming,
                 source_id: 'line-msg-222',
                 additional_attributes: {},
                 conversation: message.conversation)
        end

        let(:reply_message) do
          create(:message,
                 message_type: :outgoing,
                 content: 'no token here',
                 content_attributes: { 'in_reply_to_external_id' => quoted_message.source_id },
                 conversation: message.conversation)
        end

        before do
          quoted_message
          allow(line_client).to receive(:push_message).and_return(OpenStruct.new(code: '200', body: { 'message' => 'ok' }.to_json))
        end

        it 'sends the message without a quoteToken' do
          expect(line_client).to receive(:push_message).with(
            reply_message.conversation.contact_inbox.source_id,
            { type: 'text', text: reply_message.content }
          )

          described_class.new(message: reply_message).perform
        end
      end
    end
  end
end
