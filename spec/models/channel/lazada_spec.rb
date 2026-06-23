# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Channel::Lazada do
  let(:channel) { create(:channel_lazada) }

  describe '#get_session_detail' do
    it 'calls /im/session/get with the session_id' do
      allow(channel).to receive(:lazada_api_request).and_return(:response)

      result = channel.get_session_detail(session_id: 'sess-1')

      expect(result).to eq(:response)
      expect(channel).to have_received(:lazada_api_request).with('/im/session/get', 'GET', { session_id: 'sess-1' })
    end
  end
end
