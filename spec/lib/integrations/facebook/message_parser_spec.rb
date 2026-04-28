# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Integrations::Facebook::MessageParser do
  describe '#deleted?' do
    let(:unsend_payload) do
      { 'messaging' => { 'sender' => { 'id' => '123' }, 'recipient' => { 'id' => '456' },
                         'message' => { 'mid' => 'm_abc', 'is_deleted' => true } } }.to_json
    end
    let(:not_deleted_payload) do
      { 'messaging' => { 'sender' => { 'id' => '123' }, 'recipient' => { 'id' => '456' },
                         'message' => { 'mid' => 'm_abc', 'is_deleted' => false } } }.to_json
    end
    let(:normal_payload) do
      { 'messaging' => { 'sender' => { 'id' => '123' }, 'recipient' => { 'id' => '456' },
                         'message' => { 'mid' => 'm_abc', 'text' => 'hello' } } }.to_json
    end

    it 'returns true when message.is_deleted is true' do
      expect(described_class.new(unsend_payload).deleted?).to be true
    end

    it 'returns false when message.is_deleted is absent' do
      expect(described_class.new(normal_payload).deleted?).to be false
    end

    it 'returns false when message.is_deleted is false' do
      expect(described_class.new(not_deleted_payload).deleted?).to be false
    end
  end
end
