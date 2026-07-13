require 'rails_helper'

describe Facebook::UserProfileService do
  subject(:profile) { described_class.new(channel: facebook_channel, source_id: source_id).perform }

  # Declared ahead of the channel: creating one subscribes the page over HTTP.
  before do
    stub_request(:post, /graph.facebook.com/)
    allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
  end

  let!(:facebook_channel) { create(:channel_facebook_page) }
  let(:source_id) { '3383290475046708' }
  let(:fb_object) { double }

  # Meta refuses the Messenger User Profile API unless the app holds advanced access to the
  # "Business Asset User Profile Access" feature.
  let(:profile_access_denied) do
    Koala::Facebook::ClientError.new(400, '', {
                                       'type' => 'GraphMethodException',
                                       'message' => "Unsupported get request. Object with ID '#{source_id}' does not exist, " \
                                                    'cannot be loaded due to missing permissions, or does not support this operation.',
                                       'error_subcode' => 33,
                                       'code' => 100
                                     })
  end

  let(:thread_with_participants) do
    [{
      'participants' => {
        'data' => [
          { 'name' => 'Kantoop Patchayada', 'id' => source_id },
          { 'name' => 'The Rolling Pinn', 'id' => facebook_channel.page_id }
        ]
      },
      'id' => 't_1503994964276336'
    }]
  end

  describe '#perform' do
    it 'returns the name and avatar from the user profile api' do
      allow(fb_object).to receive(:get_object).and_return(
        { first_name: 'Jane', last_name: 'Dae', profile_pic: 'https://chatwoot-assets.local/sample.png' }.with_indifferent_access
      )
      allow(fb_object).to receive(:get_connection)

      expect(profile).to eq(name: 'Jane Dae', avatar_url: 'https://chatwoot-assets.local/sample.png')
      expect(fb_object).not_to have_received(:get_connection)
    end

    it 'falls back to the thread participants when the profile api denies access' do
      allow(fb_object).to receive(:get_object).and_raise(profile_access_denied)
      allow(fb_object).to receive(:get_connection).and_return(thread_with_participants)

      expect(profile).to eq(name: 'Kantoop Patchayada', avatar_url: nil)
      expect(fb_object).to have_received(:get_connection).with(
        facebook_channel.page_id, 'conversations', { user_id: source_id, fields: 'participants' }
      )
    end

    it 'falls back to the thread participants when the profile api returns no name' do
      allow(fb_object).to receive(:get_object).and_return({})
      allow(fb_object).to receive(:get_connection).and_return(thread_with_participants)

      expect(profile[:name]).to eq('Kantoop Patchayada')
    end

    it 'ignores the page itself when picking the participant' do
      allow(fb_object).to receive(:get_object).and_return({})
      allow(fb_object).to receive(:get_connection).and_return(
        [{ 'participants' => { 'data' => [{ 'name' => 'The Rolling Pinn', 'id' => facebook_channel.page_id }] } }]
      )

      expect(profile[:name]).to be_nil
    end

    it 'returns a nil name when the contact has no visible thread' do
      allow(fb_object).to receive(:get_object).and_return({})
      allow(fb_object).to receive(:get_connection).and_return([])

      expect(profile).to eq(name: nil, avatar_url: nil)
    end

    it 'returns a nil name when the fallback lookup itself fails' do
      allow(fb_object).to receive(:get_object).and_return({})
      allow(fb_object).to receive(:get_connection).and_raise(Koala::Facebook::ClientError.new(400, '', 'boom'))

      expect(profile[:name]).to be_nil
    end

    it 'truncates a name that would not fit the contacts.name column' do
      allow(fb_object).to receive(:get_object).and_return({ 'first_name' => 'a' * 300 })
      allow(fb_object).to receive(:get_connection)

      expect(profile[:name].length).to eq(ApplicationRecord::MAX_STRING_COLUMN_LENGTH)
    end

    it 'flags the channel and re-raises on an authentication error' do
      allow(fb_object).to receive(:get_object).and_raise(Koala::Facebook::AuthenticationError.new(500, 'Error validating access token'))

      expect { profile }.to raise_error(Koala::Facebook::AuthenticationError)
      expect(facebook_channel.reload.authorization_error_count).to eq(1)
    end
  end
end
