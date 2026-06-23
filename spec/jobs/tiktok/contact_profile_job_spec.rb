# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tiktok::ContactProfileJob do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_tiktok, account: account) }
  let(:contact) { create(:contact, account: account, name: 'abc_x_def') }
  let(:conversation_id) { 'conv-1' }
  let(:from_id) { 'user-123' }
  let(:client) { instance_double(Tiktok::Client) }

  before do
    allow(channel).to receive(:validated_access_token).and_return('token-123')
    allow(Channel::Tiktok).to receive(:find_by).with(id: channel.id).and_return(channel)
    allow(Tiktok::Client).to receive(:new)
      .with(business_id: channel.business_id, access_token: 'token-123').and_return(client)
  end

  # Get Messages (content/list) shape: data.participants[]
  def api_response(participants)
    { 'data' => { 'participants' => participants } }
  end

  def personal(id: 'user-123', profile_image: 'https://cdn.example/avatar.png')
    { 'id' => id, 'role' => 'PERSONAL_ACCOUNT', 'display_name' => 'Albert', 'profile_image' => profile_image }
  end

  def business
    { 'id' => channel.business_id, 'role' => 'BUSINESS_ACCOUNT', 'profile_image' => 'https://cdn.example/biz.png' }
  end

  def run
    described_class.perform_now(channel_id: channel.id, contact_id: contact.id,
                                conversation_id: conversation_id, from_id: from_id)
  end

  it 'enqueues the avatar download from the matching personal-account participant' do
    expect(client).to receive(:list_conversation_messages).with(conversation_id).and_return(api_response([business, personal]))
    expect(Avatar::AvatarFromUrlJob).to receive(:perform_later).with(contact, 'https://cdn.example/avatar.png')

    run
  end

  it 'matches the personal account by id among multiple participants' do
    other = personal(id: 'someone-else', profile_image: 'https://cdn.example/other.png')
    allow(client).to receive(:list_conversation_messages).and_return(api_response([other, personal(id: 'user-123')]))
    expect(Avatar::AvatarFromUrlJob).to receive(:perform_later).with(contact, 'https://cdn.example/avatar.png')

    run
  end

  it 'falls back to any personal account when no id matches' do
    allow(client).to receive(:list_conversation_messages)
      .and_return(api_response([business, personal(id: 'unexpected')]))
    expect(Avatar::AvatarFromUrlJob).to receive(:perform_later).with(contact, 'https://cdn.example/avatar.png')

    run
  end

  it 'does not change the contact name' do
    allow(client).to receive(:list_conversation_messages).and_return(api_response([personal]))
    allow(Avatar::AvatarFromUrlJob).to receive(:perform_later)

    run
    expect(contact.reload.name).to eq('abc_x_def')
  end

  it 'no-ops when the avatar is already attached' do
    contact.avatar.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: 'avatar.png')
    expect(Tiktok::Client).not_to receive(:new)
    expect(Avatar::AvatarFromUrlJob).not_to receive(:perform_later)

    run
  end

  it 'no-ops when there is no personal-account participant' do
    allow(client).to receive(:list_conversation_messages).and_return(api_response([business]))
    expect(Avatar::AvatarFromUrlJob).not_to receive(:perform_later)

    run
  end

  it 'does not enqueue when the profile_image is blank' do
    allow(client).to receive(:list_conversation_messages).and_return(api_response([personal(profile_image: nil)]))
    expect(Avatar::AvatarFromUrlJob).not_to receive(:perform_later)

    run
  end

  it 'swallows API errors so message ingestion is unaffected' do
    allow(client).to receive(:list_conversation_messages).and_raise(StandardError, 'boom')
    expect(Avatar::AvatarFromUrlJob).not_to receive(:perform_later)

    expect { run }.not_to raise_error
  end
end
