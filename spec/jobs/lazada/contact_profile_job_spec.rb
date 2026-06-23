# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lazada::ContactProfileJob do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_lazada, account: account) }
  let(:contact) { create(:contact, account: account, name: '101258560080') }
  let(:session_id) { '101201968945_2_101258560080_1_103' }
  let(:head_url) { 'https://sg-live.slatic.net/original/realbuyeravatar.png' }

  def api_response(head: head_url, success: true)
    OpenStruct.new(success?: success, body: { 'data' => { 'head_url' => head } })
  end

  def run
    described_class.perform_now(channel_id: channel.id, contact_id: contact.id, session_id: session_id)
  end

  it 'enqueues the avatar download from the session head_url' do
    expect(channel).to receive(:get_session_detail).with(session_id: session_id).and_return(api_response)
    allow(Channel::Lazada).to receive(:find_by).with(id: channel.id).and_return(channel)
    expect(Avatar::AvatarFromUrlJob).to receive(:perform_later).with(contact, head_url)

    run
  end

  it 'skips the Lazada default placeholder avatar' do
    allow(Channel::Lazada).to receive(:find_by).with(id: channel.id).and_return(channel)
    allow(channel).to receive(:get_session_detail).and_return(api_response(head: described_class::DEFAULT_AVATAR_URL))
    expect(Avatar::AvatarFromUrlJob).not_to receive(:perform_later)

    run
  end

  it 'does not enqueue when head_url is blank (expired/empty session)' do
    allow(Channel::Lazada).to receive(:find_by).with(id: channel.id).and_return(channel)
    allow(channel).to receive(:get_session_detail).and_return(api_response(head: nil))
    expect(Avatar::AvatarFromUrlJob).not_to receive(:perform_later)

    run
  end

  it 'no-ops when the API call fails' do
    allow(Channel::Lazada).to receive(:find_by).with(id: channel.id).and_return(channel)
    allow(channel).to receive(:get_session_detail).and_return(api_response(success: false))
    expect(Avatar::AvatarFromUrlJob).not_to receive(:perform_later)

    run
  end

  it 'no-ops (and skips the API call) when the avatar is already attached' do
    contact.avatar.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: 'avatar.png')
    allow(Channel::Lazada).to receive(:find_by).with(id: channel.id).and_return(channel)
    expect(channel).not_to receive(:get_session_detail)
    expect(Avatar::AvatarFromUrlJob).not_to receive(:perform_later)

    run
  end

  it 'swallows API errors so message ingestion is unaffected' do
    allow(Channel::Lazada).to receive(:find_by).with(id: channel.id).and_return(channel)
    allow(channel).to receive(:get_session_detail).and_raise(StandardError, 'boom')
    expect(Avatar::AvatarFromUrlJob).not_to receive(:perform_later)

    expect { run }.not_to raise_error
  end

  it 'does not change the contact name (Lazada masks it)' do
    allow(Channel::Lazada).to receive(:find_by).with(id: channel.id).and_return(channel)
    allow(channel).to receive(:get_session_detail).and_return(api_response)
    allow(Avatar::AvatarFromUrlJob).to receive(:perform_later)

    run
    expect(contact.reload.name).to eq('101258560080')
  end
end
