require 'rails_helper'

RSpec.describe AutoAssignment::AssignmentJob, type: :job do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true) }
  let(:agent) { create(:user, account: account, role: :agent, availability: :online) }

  before do
    create(:inbox_member, inbox: inbox, user: agent)
  end

  describe '#perform' do
    context 'when inbox exists' do
      context 'when auto assignment is enabled' do
        it 'calls the assignment service' do
          service = instance_double(AutoAssignment::AssignmentService)
          allow(AutoAssignment::AssignmentService).to receive(:new).with(inbox: inbox).and_return(service)
          expect(service).to receive(:perform_bulk_assignment).with(limit: 100).and_return(5)

          described_class.new.perform(inbox_id: inbox.id)
        end

        it 'logs the assignment count' do
          service = instance_double(AutoAssignment::AssignmentService)
          allow(AutoAssignment::AssignmentService).to receive(:new).and_return(service)
          allow(service).to receive(:perform_bulk_assignment).and_return(3)
          allow(Rails.logger).to receive(:info)

          described_class.new.perform(inbox_id: inbox.id)

          expect(Rails.logger).to have_received(:info).with("Assigned 3 conversations for inbox #{inbox.id}")
        end

        it 'uses custom bulk limit from environment' do
          allow(ENV).to receive(:fetch).with('AUTO_ASSIGNMENT_BULK_LIMIT', 100).and_return('50')

          service = instance_double(AutoAssignment::AssignmentService)
          allow(AutoAssignment::AssignmentService).to receive(:new).with(inbox: inbox).and_return(service)
          expect(service).to receive(:perform_bulk_assignment).with(limit: 50).and_return(2)

          described_class.new.perform(inbox_id: inbox.id)
        end
      end

      context 'when auto assignment is disabled' do
        before { inbox.update!(enable_auto_assignment: false) }

        it 'calls the service which handles the disabled state' do
          service = instance_double(AutoAssignment::AssignmentService)
          allow(AutoAssignment::AssignmentService).to receive(:new).with(inbox: inbox).and_return(service)
          expect(service).to receive(:perform_bulk_assignment).with(limit: 100).and_return(0)

          described_class.new.perform(inbox_id: inbox.id)
        end
      end
    end

    context 'when inbox does not exist' do
      it 'returns early without processing' do
        expect(AutoAssignment::AssignmentService).not_to receive(:new)

        described_class.new.perform(inbox_id: 999_999)
      end
    end

    context 'when an error occurs' do
      it 'logs the error and re-raises in test environment' do
        service = instance_double(AutoAssignment::AssignmentService)
        allow(AutoAssignment::AssignmentService).to receive(:new).and_return(service)
        allow(service).to receive(:perform_bulk_assignment).and_raise(StandardError, 'Something went wrong')
        allow(Rails.logger).to receive(:error)

        expect do
          described_class.new.perform(inbox_id: inbox.id)
        end.to raise_error(StandardError, 'Something went wrong')

        expect(Rails.logger).to have_received(:error).with("Bulk assignment failed for inbox #{inbox.id}: Something went wrong")
      end
    end
  end

  describe '.enqueue_for_inbox' do
    after do
      Redis::Alfred.delete(format(Redis::Alfred::AUTO_ASSIGNMENT_IN_FLIGHT_KEY, inbox_id: inbox.id))
      Redis::Alfred.delete(described_class.pending_key(inbox.id))
    end

    it 'enqueues one run per inbox and coalesces concurrent triggers' do
      allow(described_class).to receive(:perform_later).and_return(true)

      expect(described_class.enqueue_for_inbox(inbox.id)).to be(true)
      expect(described_class.enqueue_for_inbox(inbox.id)).to be(false)
      expect(described_class).to have_received(:perform_later).once
    end

    it 'does not release a newer run marker when its own token is stale' do
      key = format(Redis::Alfred::AUTO_ASSIGNMENT_IN_FLIGHT_KEY, inbox_id: inbox.id)
      Redis::Alfred.set(key, 'newer-token', ex: 300)
      allow(AutoAssignment::AssignmentService).to receive(:new)
        .and_return(instance_double(AutoAssignment::AssignmentService, perform_bulk_assignment: 0))

      described_class.new.perform(inbox_id: inbox.id, token: 'stale-token')

      expect(Redis::Alfred.get(key)).to eq('newer-token')
    end

    it 'marks the inbox pending when a trigger is turned away by the gate' do
      allow(described_class).to receive(:perform_later).and_return(true)

      described_class.enqueue_for_inbox(inbox.id)
      expect(Redis::Alfred.get(described_class.pending_key(inbox.id))).to be_nil

      described_class.enqueue_for_inbox(inbox.id)
      expect(Redis::Alfred.get(described_class.pending_key(inbox.id))).to eq('1')
    end
  end

  describe 'replaying coalesced triggers' do
    after do
      Redis::Alfred.delete(format(Redis::Alfred::AUTO_ASSIGNMENT_IN_FLIGHT_KEY, inbox_id: inbox.id))
      Redis::Alfred.delete(described_class.pending_key(inbox.id))
    end

    before do
      allow(AutoAssignment::AssignmentService).to receive(:new)
        .and_return(instance_double(AutoAssignment::AssignmentService, perform_bulk_assignment: 0))
    end

    it 'enqueues exactly one more run when a trigger was skipped mid-flight' do
      Redis::Alfred.set(described_class.pending_key(inbox.id), '1', ex: 300)

      expect { described_class.new.perform(inbox_id: inbox.id) }
        .to have_enqueued_job(described_class).with(hash_including(inbox_id: inbox.id)).once
      expect(Redis::Alfred.get(described_class.pending_key(inbox.id))).to be_nil
    end

    it 'does not enqueue a follow-up run when no trigger was skipped' do
      expect { described_class.new.perform(inbox_id: inbox.id) }.not_to have_enqueued_job(described_class)
    end

    it 'replays even when the assignment service raises' do
      allow(AutoAssignment::AssignmentService).to receive(:new)
        .and_return(instance_double(AutoAssignment::AssignmentService).tap do |service|
          allow(service).to receive(:perform_bulk_assignment).and_raise(StandardError, 'boom')
        end)
      Redis::Alfred.set(described_class.pending_key(inbox.id), '1', ex: 300)

      expect do
        expect { described_class.new.perform(inbox_id: inbox.id) }.to raise_error(StandardError, 'boom')
      end.to have_enqueued_job(described_class).once
    end
  end

  describe 'job configuration' do
    it 'is queued in the default queue' do
      expect(described_class.queue_name).to eq('default')
    end
  end
end
