# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tiktok::Shop::ContactProfileJob do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_tiktok_shop, account: account) }
  let(:contact) { create(:contact, account: account, name: 'u123') }
  let(:conversation_id) { 'conv-1' }
  let(:im_user_id) { 'u123' }
  let(:client) { instance_double(Tiktok::Shop::Client) }

  before { allow(Tiktok::Shop::Client).to receive(:new).with(channel: channel).and_return(client) }

  def api_response(messages:, success: true)
    OpenStruct.new(success?: success, body: { 'data' => { 'messages' => messages } })
  end

  def buyer_message(uid: 'u123', nickname: 'Albert', avatar: 'https://cdn.example/avatar.png')
    { 'sender' => { 'im_user_id' => uid, 'role' => 'BUYER', 'nickname' => nickname, 'avatar' => avatar } }
  end

  def run
    described_class.perform_now(channel_id: channel.id, contact_id: contact.id,
                                conversation_id: conversation_id, im_user_id: im_user_id)
  end

  it 'sets the contact name from the buyer nickname and enqueues the avatar download' do
    allow(client).to receive(:get_conversation_messages).and_return(api_response(messages: [buyer_message]))
    expect(Avatar::AvatarFromUrlJob).to receive(:perform_later).with(contact, 'https://cdn.example/avatar.png')

    run
    expect(contact.reload.name).to eq('Albert')
  end

  it 'matches the buyer by im_user_id when multiple participants are present' do
    other = { 'sender' => { 'im_user_id' => 'shop1', 'role' => 'SHOP', 'nickname' => 'Shop', 'avatar' => 'x' } }
    allow(client).to receive(:get_conversation_messages)
      .and_return(api_response(messages: [other, buyer_message(uid: 'u123', nickname: 'Buyer123')]))
    allow(Avatar::AvatarFromUrlJob).to receive(:perform_later)

    run
    expect(contact.reload.name).to eq('Buyer123')
  end

  it 'does not overwrite a name that is no longer the placeholder' do
    contact.update!(name: 'Renamed By Agent')
    allow(client).to receive(:get_conversation_messages).and_return(api_response(messages: [buyer_message]))
    allow(Avatar::AvatarFromUrlJob).to receive(:perform_later)

    run
    expect(contact.reload.name).to eq('Renamed By Agent')
  end

  it 'no-ops when the API call fails' do
    allow(client).to receive(:get_conversation_messages).and_return(api_response(messages: [], success: false))
    expect(Avatar::AvatarFromUrlJob).not_to receive(:perform_later)

    run
    expect(contact.reload.name).to eq('u123')
  end

  it 'no-ops when no buyer sender is present' do
    shop = { 'sender' => { 'im_user_id' => 's1', 'role' => 'SHOP', 'nickname' => 'Shop', 'avatar' => 'x' } }
    allow(client).to receive(:get_conversation_messages).and_return(api_response(messages: [shop]))
    expect(Avatar::AvatarFromUrlJob).not_to receive(:perform_later)

    run
    expect(contact.reload.name).to eq('u123')
  end

  it 'does not enqueue an avatar download when the avatar is blank' do
    allow(client).to receive(:get_conversation_messages)
      .and_return(api_response(messages: [buyer_message(avatar: nil)]))
    expect(Avatar::AvatarFromUrlJob).not_to receive(:perform_later)

    run
    expect(contact.reload.name).to eq('Albert')
  end
end
