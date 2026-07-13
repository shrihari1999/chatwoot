require 'rails_helper'

describe Webhooks::InstagramEventsJob do
  subject(:instagram_webhook) { described_class }

  before do
    stub_request(:post, /graph\.facebook\.com/)
    stub_request(:get, 'https://www.example.com/test.jpeg')
      .to_return(status: 200, body: '', headers: {})
    stub_request(:get, 'https://lookaside.fbsbx.com/ig_messaging_cdn/?asset_id=17949487764033669&signature=test')
      .to_return(status: 200, body: '', headers: {})
    stub_request(:get, 'https://lookaside.fbsbx.com/ig_messaging_cdn/?asset_id=18091626484740369&signature=test')
      .to_return(status: 200, body: '', headers: {})
  end

  let!(:account) { create(:account) }

  def return_object_for(sender_id)
    { name: 'Jane',
      id: sender_id,
      account_id: instagram_messenger_inbox.account_id,
      profile_pic: 'https://chatwoot-assets.local/sample.png',
      username: 'some_user_name' }
  end

  describe '#perform' do
    context 'when handling messaging events for Instagram via Facebook page' do
      let!(:instagram_messenger_channel) { create(:channel_instagram_fb_page, account: account, instagram_id: 'chatwoot-app-user-id-1') }
      let!(:instagram_messenger_inbox) { create(:inbox, channel: instagram_messenger_channel, account: account, greeting_enabled: false) }
      let(:fb_object) { double }

      it 'creates incoming message in the instagram inbox' do
        dm_event = build(:instagram_message_create_event).with_indifferent_access
        sender_id = dm_event[:entry][0][:messaging][0][:sender][:id]

        allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
        allow(fb_object).to receive(:get_object).and_return(
          return_object_for(sender_id).with_indifferent_access
        )
        instagram_webhook.perform_now(dm_event[:entry])

        expect(instagram_messenger_inbox.contacts.count).to be 1
        expect(instagram_messenger_inbox.contacts.last.additional_attributes['social_instagram_user_name']).to eq 'some_user_name'
        expect(instagram_messenger_inbox.conversations.count).to be 1
        expect(instagram_messenger_inbox.messages.count).to be 1
        expect(instagram_messenger_inbox.messages.last.content_attributes['is_unsupported']).to be_nil
      end

      it 'creates standby message in the instagram inbox' do
        standby_event = build(:instagram_message_standby_event).with_indifferent_access
        sender_id = standby_event[:entry][0][:standby][0][:sender][:id]

        allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
        allow(fb_object).to receive(:get_object).and_return(
          return_object_for(sender_id).with_indifferent_access
        )
        instagram_webhook.perform_now(standby_event[:entry])

        expect(instagram_messenger_inbox.contacts.count).to be 1
        expect(instagram_messenger_inbox.contacts.last.additional_attributes['social_instagram_user_name']).to eq 'some_user_name'
        expect(instagram_messenger_inbox.conversations.count).to be 1
        expect(instagram_messenger_inbox.messages.count).to be 1

        message = instagram_messenger_inbox.messages.last
        expect(message.content).to eq('This is the first standby message from the customer, after 24 hours.')
      end

      it 'handle instagram unsend message event' do
        unsend_event = build(:instagram_message_unsend_event).with_indifferent_access
        sender_id = unsend_event[:entry][0][:messaging][0][:sender][:id]

        message = create(:message, inbox_id: instagram_messenger_inbox.id, source_id: 'message-id-to-delete')
        allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
        allow(fb_object).to receive(:get_object).and_return(
          {
            name: 'Jane',
            id: sender_id,
            account_id: instagram_messenger_inbox.account_id,
            profile_pic: 'https://chatwoot-assets.local/sample.png'
          }.with_indifferent_access
        )
        message.attachments.new(file_type: :image, external_url: 'https://www.example.com/test.jpeg')

        expect(instagram_messenger_inbox.messages.count).to be 1

        instagram_webhook.perform_now(unsend_event[:entry])

        expect(instagram_messenger_inbox.messages.last.content).to eq 'This message was deleted'
        expect(instagram_messenger_inbox.messages.last.deleted).to be true
        expect(instagram_messenger_inbox.messages.last.attachments.count).to be 0
        expect(instagram_messenger_inbox.messages.last.reload.deleted).to be true
      end

      it 'creates incoming message with attachments in the instagram inbox' do
        attachment_event = build(:instagram_message_attachment_event).with_indifferent_access
        sender_id = attachment_event[:entry][0][:messaging][0][:sender][:id]

        allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
        allow(fb_object).to receive(:get_object).and_return(
          return_object_for(sender_id).with_indifferent_access
        )
        instagram_webhook.perform_now(attachment_event[:entry])

        expect(instagram_messenger_inbox.contacts.count).to be 1
        expect(instagram_messenger_inbox.messages.count).to be 1
        expect(instagram_messenger_inbox.messages.last.attachments.count).to be 1
      end

      it 'creates incoming message with attachments in the instagram inbox for story mention' do
        story_mention_event = build(:instagram_story_mention_event).with_indifferent_access
        sender_id = story_mention_event[:entry][0][:messaging][0][:sender][:id]

        allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
        allow(fb_object).to receive(:get_object).and_return(
          return_object_for(sender_id).with_indifferent_access,
          { story:
            {
              mention: {
                link: 'https://www.example.com/test.jpeg',
                id: '17920786367196703'
              }
            },
            from: {
              username: 'Sender-id-1', id: 'Sender-id-1'
            },
            id: 'instagram-message-id-1234' }.with_indifferent_access
        )

        instagram_webhook.perform_now(story_mention_event[:entry])

        expect(instagram_messenger_inbox.messages.count).to be 1
        expect(instagram_messenger_inbox.messages.last.attachments.count).to be 1

        attachment = instagram_messenger_inbox.messages.last.attachments.last
        expect(attachment.push_event_data[:data_url]).to eq(attachment.external_url)
      end

      it 'creates incoming message with ig_story attachment in the instagram inbox' do
        ig_story_event = build(:instagram_ig_story_event).with_indifferent_access
        sender_id = ig_story_event[:entry][0][:messaging][0][:sender][:id]

        allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
        allow(fb_object).to receive(:get_object).and_return(
          return_object_for(sender_id).with_indifferent_access
        )

        instagram_webhook.perform_now(ig_story_event[:entry])

        expect(instagram_messenger_inbox.messages.count).to be 1
        expect(instagram_messenger_inbox.messages.last.attachments.count).to be 1

        message = instagram_messenger_inbox.messages.last
        attachment = message.attachments.last

        expect(attachment.file_type).to eq 'ig_story'
        expect(attachment.external_url).to include 'lookaside.fbsbx.com'
        expect(message.content).to eq 'Shared story'
        expect(message.content_attributes['image_type']).to eq 'ig_story'
      end

      it 'creates incoming message with ig_post attachment in the instagram inbox' do
        ig_post_event = build(:instagram_ig_post_event).with_indifferent_access
        sender_id = ig_post_event[:entry][0][:messaging][0][:sender][:id]

        allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
        allow(fb_object).to receive(:get_object).and_return(
          return_object_for(sender_id).with_indifferent_access
        )

        instagram_webhook.perform_now(ig_post_event[:entry])

        expect(instagram_messenger_inbox.messages.count).to be 1
        expect(instagram_messenger_inbox.messages.last.attachments.count).to be 1

        message = instagram_messenger_inbox.messages.last
        attachment = message.attachments.last

        expect(attachment.file_type).to eq 'ig_post'
        expect(attachment.external_url).to include 'ig_messaging_cdn'
        expect(message.content).to eq 'Shared post'
        expect(message.content_attributes['image_type']).to eq 'ig_post'
      end

      it 'does not create contact or messages when Facebook API call fails' do
        story_mention_echo_event = build(:instagram_story_mention_event_with_echo).with_indifferent_access

        allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
        allow(fb_object).to receive(:get_object).and_raise(Koala::Facebook::ClientError)

        instagram_webhook.perform_now(story_mention_echo_event[:entry])

        expect(instagram_messenger_inbox.contacts.count).to be 0
        expect(instagram_messenger_inbox.contact_inboxes.count).to be 0
        expect(instagram_messenger_inbox.messages.count).to be 0
      end

      it 'handle messaging_seen callback' do
        messaging_seen_event = build(:messaging_seen_event).with_indifferent_access

        expect(Instagram::ReadStatusService).to receive(:new).with(params: messaging_seen_event[:entry][0][:messaging][0],
                                                                   channel: instagram_messenger_inbox.channel).and_call_original
        instagram_webhook.perform_now(messaging_seen_event[:entry])
      end

      it 'routes reaction event to Instagram::MessageReactionService' do
        reaction_event = {
          entry: [
            {
              id: SecureRandom.uuid,
              time: '2021-09-08T06:34:04+0000',
              messaging: [
                {
                  sender: { id: 'Sender-id-1' },
                  recipient: { id: 'chatwoot-app-user-id-1' },
                  timestamp: '2021-09-08T06:34:04+0000',
                  reaction: { mid: 'mid.test123', action: 'react', emoji: '❤️' }
                }
              ]
            }
          ]
        }.with_indifferent_access

        service = instance_double(Instagram::MessageReactionService)
        allow(Instagram::MessageReactionService).to receive(:new).and_return(service)
        allow(service).to receive(:perform)

        instagram_webhook.perform_now(reaction_event[:entry])

        expect(Instagram::MessageReactionService).to have_received(:new).with(
          params: reaction_event[:entry][0][:messaging][0],
          channel: instagram_messenger_inbox.channel
        )
        expect(service).to have_received(:perform)
      end

      it 'updates message content on message_edit event' do
        original = create(:message, inbox: instagram_messenger_inbox, account: account,
                                    source_id: 'message-id-to-edit', content: 'original text')

        edit_event = build(:instagram_message_edit_event,
                           text: 'edited via instagram').with_indifferent_access

        instagram_webhook.perform_now(edit_event[:entry])

        original.reload
        expect(original.content).to eq('edited via instagram')
        expect(original.edited).to be true
      end

      it 'handles unsupported message' do
        unsupported_event = build(:instagram_message_unsupported_event).with_indifferent_access
        sender_id = unsupported_event[:entry][0][:messaging][0][:sender][:id]

        allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
        allow(fb_object).to receive(:get_object).and_return(
          return_object_for(sender_id).with_indifferent_access
        )

        instagram_webhook.perform_now(unsupported_event[:entry])
        expect(instagram_messenger_inbox.contacts.count).to be 1
        expect(instagram_messenger_inbox.contacts.last.additional_attributes['social_instagram_user_name']).to eq 'some_user_name'
        expect(instagram_messenger_inbox.conversations.count).to be 1
        expect(instagram_messenger_inbox.messages.count).to be 1
        expect(instagram_messenger_inbox.messages.last.content_attributes['is_unsupported']).to be true
      end
    end

    context 'when handling messaging events for Instagram via Instagram login' do
      let!(:instagram_channel) { create(:channel_instagram, account: account, instagram_id: 'chatwoot-app-user-id-1') }
      let!(:instagram_inbox) { instagram_channel.inbox }

      before do
        instagram_channel.update(access_token: 'valid_instagram_token')

        stub_request(:get, %r{https://graph\.instagram\.com/v22\.0/Sender-id-.*\?.*})
          .to_return(
            status: 200,
            body: proc { |request|
              sender_id = request.uri.path.split('/').last.split('?').first
              {
                name: 'Jane',
                username: 'some_user_name',
                profile_pic: 'https://chatwoot-assets.local/sample.png',
                id: sender_id,
                follower_count: 100,
                is_user_follow_business: true,
                is_business_follow_user: true,
                is_verified_user: false
              }.to_json
            },
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'creates incoming message with correct contact info in the instagram direct inbox' do
        dm_event = build(:instagram_message_create_event).with_indifferent_access
        instagram_webhook.perform_now(dm_event[:entry])
        expect(instagram_inbox.contacts.count).to eq 1
        expect(instagram_inbox.contacts.last.additional_attributes['social_instagram_user_name']).to eq 'some_user_name'
        expect(instagram_inbox.conversations.count).to eq 1
        expect(instagram_inbox.messages.count).to eq 1
        expect(instagram_inbox.messages.last.content_attributes['is_unsupported']).to be_nil
      end

      it 'names the contact with the display name when instagram returns one' do
        dm_event = build(:instagram_message_create_event).with_indifferent_access
        instagram_webhook.perform_now(dm_event[:entry])

        expect(instagram_inbox.contacts.last.name).to eq 'Jane'
      end

      # Instagram omits `name` entirely for users who never set a display name.
      it 'names the contact with the username when instagram returns no display name' do
        stub_request(:get, %r{https://graph\.instagram\.com/v22\.0/Sender-id-.*\?.*})
          .to_return(
            status: 200,
            body: proc { |request|
              sender_id = request.uri.path.split('/').last.split('?').first
              { username: 'notacouch_potatoo', profile_pic: 'https://chatwoot-assets.local/sample.png', id: sender_id }.to_json
            },
            headers: { 'Content-Type' => 'application/json' }
          )

        dm_event = build(:instagram_message_create_event).with_indifferent_access
        instagram_webhook.perform_now(dm_event[:entry])

        contact = instagram_inbox.contacts.last
        expect(contact.name).to eq 'notacouch_potatoo'
        expect(contact.additional_attributes['social_instagram_user_name']).to eq 'notacouch_potatoo'
      end

      it 'sets correct instagram attributes on contact' do
        dm_event = build(:instagram_message_create_event).with_indifferent_access
        instagram_webhook.perform_now(dm_event[:entry])
        instagram_inbox.reload

        contact = instagram_inbox.contacts.last

        expect(contact.additional_attributes['social_instagram_follower_count']).to eq 100
        expect(contact.additional_attributes['social_instagram_is_user_follow_business']).to be true
        expect(contact.additional_attributes['social_instagram_is_business_follow_user']).to be true
        expect(contact.additional_attributes['social_instagram_is_verified_user']).to be false
      end

      it 'handle instagram unsend message event' do
        unsend_event = build(:instagram_message_unsend_event).with_indifferent_access

        message = create(:message, inbox_id: instagram_inbox.id, source_id: 'message-id-to-delete', content: 'random_text')

        # Create attachment correctly with account association
        message.attachments.create!(
          file_type: :image,
          external_url: 'https://www.example.com/test.jpeg',
          account_id: instagram_inbox.account_id
        )

        expect(instagram_inbox.messages.count).to be 1

        instagram_webhook.perform_now(unsend_event[:entry])

        message.reload

        expect(message.content).to eq 'This message was deleted'
        expect(message.deleted).to be true
        expect(message.attachments.count).to be 0
      end

      it 'creates incoming message with attachments in the instagram direct inbox' do
        attachment_event = build(:instagram_message_attachment_event).with_indifferent_access
        instagram_webhook.perform_now(attachment_event[:entry])

        expect(instagram_inbox.contacts.count).to be 1
        expect(instagram_inbox.messages.count).to be 1
        expect(instagram_inbox.messages.last.attachments.count).to be 1
      end

      it 'handles unsupported message' do
        unsupported_event = build(:instagram_message_unsupported_event).with_indifferent_access
        instagram_webhook.perform_now(unsupported_event[:entry])
        expect(instagram_inbox.contacts.count).to be 1
        expect(instagram_inbox.contacts.last.additional_attributes['social_instagram_user_name']).to eq 'some_user_name'
        expect(instagram_inbox.conversations.count).to be 1
        expect(instagram_inbox.messages.count).to be 1
        expect(instagram_inbox.messages.last.content_attributes['is_unsupported']).to be true
      end

      it 'creates incoming message with ig_story attachment in the instagram direct inbox' do
        ig_story_event = build(:instagram_ig_story_event).with_indifferent_access
        instagram_webhook.perform_now(ig_story_event[:entry])

        expect(instagram_inbox.messages.count).to be 1
        expect(instagram_inbox.messages.last.attachments.count).to be 1

        message = instagram_inbox.messages.last
        attachment = message.attachments.last

        expect(attachment.file_type).to eq 'ig_story'
        expect(attachment.external_url).to include 'lookaside.fbsbx.com'
        expect(message.content).to eq 'Shared story'
        expect(message.content_attributes['image_type']).to eq 'ig_story'
      end

      it 'creates incoming message with ig_post attachment in the instagram direct inbox' do
        ig_post_event = build(:instagram_ig_post_event).with_indifferent_access
        instagram_webhook.perform_now(ig_post_event[:entry])

        expect(instagram_inbox.messages.count).to be 1
        expect(instagram_inbox.messages.last.attachments.count).to be 1

        message = instagram_inbox.messages.last
        attachment = message.attachments.last

        expect(attachment.file_type).to eq 'ig_post'
        expect(attachment.external_url).to include 'ig_messaging_cdn'
        expect(message.content).to eq 'Shared post'
        expect(message.content_attributes['image_type']).to eq 'ig_post'
      end

      it 'does not create contact or messages when Instagram API call fails' do
        story_mention_echo_event = build(:instagram_story_mention_event_with_echo).with_indifferent_access

        stub_request(:get, %r{https://graph\.instagram\.com/v22\.0/.*\?.*})
          .to_return(status: 401, body: { error: { message: 'Invalid OAuth access token' } }.to_json)

        instagram_webhook.perform_now(story_mention_echo_event[:entry])

        expect(instagram_inbox.contacts.count).to be 0
        expect(instagram_inbox.contact_inboxes.count).to be 0
        expect(instagram_inbox.messages.count).to be 0
      end

      it 'handles messaging_seen callback' do
        messaging_seen_event = build(:messaging_seen_event).with_indifferent_access

        expect(Instagram::ReadStatusService).to receive(:new).with(params: messaging_seen_event[:entry][0][:messaging][0],
                                                                   channel: instagram_inbox.channel).and_call_original
        instagram_webhook.perform_now(messaging_seen_event[:entry])
      end

      it 'routes reaction event to Instagram::MessageReactionService' do
        reaction_event = {
          entry: [
            {
              id: SecureRandom.uuid,
              time: '2021-09-08T06:34:04+0000',
              messaging: [
                {
                  sender: { id: 'Sender-id-1' },
                  recipient: { id: 'chatwoot-app-user-id-1' },
                  timestamp: '2021-09-08T06:34:04+0000',
                  reaction: { mid: 'mid.test123', action: 'react', emoji: '❤️' }
                }
              ]
            }
          ]
        }.with_indifferent_access

        service = instance_double(Instagram::MessageReactionService)
        allow(Instagram::MessageReactionService).to receive(:new).and_return(service)
        allow(service).to receive(:perform)

        instagram_webhook.perform_now(reaction_event[:entry])

        expect(Instagram::MessageReactionService).to have_received(:new).with(
          params: reaction_event[:entry][0][:messaging][0],
          channel: instagram_inbox.channel
        )
        expect(service).to have_received(:perform)
      end

      it 'updates message content on message_edit event' do
        original = create(:message, inbox: instagram_inbox, account: account,
                                    source_id: 'message-id-to-edit', content: 'original text')

        edit_event = build(:instagram_message_edit_event,
                           text: 'edited via instagram direct').with_indifferent_access

        instagram_webhook.perform_now(edit_event[:entry])

        original.reload
        expect(original.content).to eq('edited via instagram direct')
        expect(original.edited).to be true
      end

      it 'creates contact when Instagram API call returns `No matching Instagram user` (9010 error code)' do
        stub_request(:get, %r{https://graph\.instagram\.com/v22\.0/.*\?.*})
          .to_return(status: 401, body: { error: { message: 'No matching Instagram user', code: 9010 } }.to_json)

        dm_event = build(:instagram_message_create_event).with_indifferent_access
        sender_id = dm_event[:entry][0][:messaging][0][:sender][:id]
        instagram_webhook.perform_now(dm_event[:entry])

        expect(instagram_inbox.contacts.count).to be 1
        expect(instagram_inbox.contacts.last.name).to eq "Unknown (IG: #{sender_id})"
        expect(instagram_inbox.contacts.last.contact_inboxes.count).to be 1
        expect(instagram_inbox.contacts.last.contact_inboxes.first.source_id).to eq sender_id

        expect(instagram_inbox.conversations.count).to eq 1
        expect(instagram_inbox.messages.count).to eq 1
        expect(instagram_inbox.messages.last.content_attributes['is_unsupported']).to be_nil
      end
    end

    context 'when routing `changes:` payloads (test events vs comments)' do
      # Meta delivers BOTH dev-dashboard test events AND real post-comment
      # webhooks under the same `changes:` payload shape. The job must
      # distinguish them by the `field` value — only "messages" is the
      # dev-dashboard test event; "comments" is a real post comment.
      let!(:instagram_channel) { create(:channel_instagram, account: account, instagram_id: 'BUSINESS_IGSID') }
      let!(:instagram_inbox)   { instagram_channel.inbox }

      before do
        # CommentService does a best-effort permalink lookup; stub so the
        # event-routing tests don't depend on real network.
        stub_request(:get, %r{graph\.instagram\.com/v\d+\.\d+/POST_MEDIA_ID})
          .with(query: hash_including('fields' => 'permalink'))
          .to_return(status: 200, body: { permalink: 'https://www.instagram.com/p/CeVsUJlBsHN/' }.to_json,
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'routes field=comments to Instagram::CommentService' do
        comment_entry = [
          {
            id: 'BUSINESS_IGSID',
            time: 1_778_500_000,
            changes: [
              {
                field: 'comments',
                value: {
                  id: '18094947671518722',
                  from: { id: 'COMMENTER_IGSID', username: 'shrihari.12' },
                  media: { id: 'POST_MEDIA_ID', media_product_type: 'FEED' },
                  text: 'Test comment'
                }
              }
            ]
          }
        ].as_json

        instagram_webhook.perform_now(comment_entry)

        msg = instagram_inbox.messages.last
        expect(msg).to be_present
        expect(msg.content).to eq 'Test comment'
        expect(msg.content_attributes['source_type']).to eq 'instagram_comment'
        expect(msg.content_attributes['comment_id']).to eq '18094947671518722'
      end

      it 'still routes field=messages to TestEventService (dev-dashboard test event)' do
        test_event = [
          {
            id: '0',
            time: 1_778_500_000,
            changes: [
              {
                field: 'messages',
                value: {
                  sender: { id: '12334' },
                  recipient: { id: '23245' },
                  timestamp: '1527459824',
                  message: { mid: 'random_mid', text: 'random_text' }
                }
              }
            ]
          }
        ].as_json

        expect(Instagram::TestEventService).to receive(:new).and_call_original
        instagram_webhook.perform_now(test_event)
      end

      it 'ignores unknown changes.field values without erroring' do
        unknown_entry = [
          {
            id: 'BUSINESS_IGSID',
            time: 1_778_500_000,
            changes: [{ field: 'mentions', value: { id: 'whatever' } }]
          }
        ].as_json

        expect { instagram_webhook.perform_now(unknown_entry) }.not_to raise_error
        expect(instagram_inbox.messages).to be_empty
      end
    end
  end
end
