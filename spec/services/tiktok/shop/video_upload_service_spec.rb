# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tiktok::Shop::VideoUploadService do
  let(:account) { create(:account) }
  let(:init_ok) do
    OpenStruct.new(success?: true, body: { 'data' => { 'upload_url' => 'https://up/load', 'upload_token' => 'tok' } })
  end
  let(:channel) { create(:channel_tiktok_shop, account: account) }
  let(:client) { instance_double(Tiktok::Shop::Client) }

  before { allow(Tiktok::Shop::Client).to receive(:new).with(channel: channel).and_return(client) }

  def service(bytes)
    described_class.new(channel: channel, conversation_id: 'c1', bytes: bytes,
                        filename: 'v.mp4', content_type: 'video/mp4')
  end

  it 'uploads a small video as a single chunk and returns the resource_id' do
    allow(client).to receive(:init_file_upload).and_return(init_ok)
    allow(client).to receive(:upload_file_chunk).and_return(OpenStruct.new(success?: true, body: { 'resource_id' => 'vid-1' }))

    expect(service('small-bytes').perform).to eq('vid-1')
    expect(client).to have_received(:upload_file_chunk).once
  end

  it 'splits a large video into multiple chunks and returns the final resource_id' do
    big = 'x' * (50 * 1024 * 1024) # 50 MB -> 20 + 20 + 10 = 3 chunks
    captured = nil
    allow(client).to receive(:init_file_upload) { |**kw| captured = kw and init_ok }
    allow(client).to receive(:upload_file_chunk).and_return(
      OpenStruct.new(success?: true, body: { 'part_id' => 'p1' }),
      OpenStruct.new(success?: true, body: { 'part_id' => 'p2' }),
      OpenStruct.new(success?: true, body: { 'resource_id' => 'vid-final' })
    )

    expect(service(big).perform).to eq('vid-final')
    expect(client).to have_received(:upload_file_chunk).exactly(3).times
    expect(captured[:total_chunk_count]).to eq(3)
    expect(captured[:target_path]).to eq('[POST]/customer_service/202606/conversations/c1/messages')
  end

  it 'returns nil when init fails' do
    allow(client).to receive(:init_file_upload).and_return(OpenStruct.new(success?: false, code: 1, message: 'bad', body: {}))
    expect(client).not_to receive(:upload_file_chunk)

    expect(service('x').perform).to be_nil
  end

  it 'returns nil when a chunk upload fails' do
    allow(client).to receive(:init_file_upload).and_return(init_ok)
    allow(client).to receive(:upload_file_chunk).and_return(OpenStruct.new(success?: false, code: 2, message: 'fail', body: {}))

    expect(service('x').perform).to be_nil
  end
end
