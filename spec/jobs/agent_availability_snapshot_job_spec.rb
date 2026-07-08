require 'rails_helper'

RSpec.describe AgentAvailabilitySnapshotJob do
  # NB: a plain method, not a memoized `subject`, so tests that trigger the job
  # more than once actually re-run it each time.
  def run_snapshot
    described_class.perform_now
  end

  let(:account) { create(:account) }
  let(:user) { create(:user) }
  # Setup object the job iterates over; not referenced directly in examples.
  let!(:account_user) { create(:account_user, account: account, user: user, role: :agent) } # rubocop:disable RSpec/LetSetup

  # auto_offline defaults to true, so effective availability is driven by the
  # Redis heartbeat + status — exactly what these helpers manipulate.
  def mark_present(status)
    OnlineStatusTracker.update_presence(account.id, 'AccountUser', user.id)
    OnlineStatusTracker.set_status(account.id, user.id, status)
  end

  def mark_disconnected
    # Drop the heartbeat entirely so the agent reads as offline (mirrors a closed tab).
    Redis::Alfred.delete(OnlineStatusTracker.presence_key(account.id, 'AccountUser'))
  end

  def latest
    AgentAvailabilityPeriod.where(user_id: user.id).order(:started_at).last
  end

  describe '#perform' do
    it 'opens an offline period when the agent has no live presence' do
      mark_disconnected

      expect { run_snapshot }.to change { AgentAvailabilityPeriod.where(user_id: user.id).count }.by(1)
      expect(latest).to have_attributes(status: 'offline', ended_at: nil)
    end

    it 'opens an online period when the agent is present and online' do
      mark_present('online')

      run_snapshot
      expect(latest).to have_attributes(status: 'online', ended_at: nil)
    end

    it 'does not write a new period while the status is unchanged' do
      mark_present('online')
      run_snapshot

      expect { run_snapshot }.not_to(change { AgentAvailabilityPeriod.where(user_id: user.id).count })
      expect(AgentAvailabilityPeriod.open.where(user_id: user.id).count).to eq(1)
    end

    it 'closes the open period and opens a new one on a transition' do
      mark_present('online')
      run_snapshot
      first = latest

      mark_disconnected
      expect { run_snapshot }.to change { AgentAvailabilityPeriod.where(user_id: user.id).count }.by(1)

      expect(first.reload.ended_at).to be_present
      expect(latest).to have_attributes(status: 'offline', ended_at: nil)
      expect(latest.started_at).to eq(first.ended_at)
    end

    it 'records a busy status distinctly from online' do
      mark_present('busy')
      run_snapshot

      expect(latest.status).to eq('busy')
    end

    it 'enforces a single open period per agent' do
      mark_present('online')
      run_snapshot
      mark_disconnected
      run_snapshot

      expect(AgentAvailabilityPeriod.open.where(user_id: user.id).count).to eq(1)
    end
  end

  describe 'assign-on-agent-online trigger' do
    let(:inbox) { create(:inbox, account: account) }
    let!(:inbox_member) { create(:inbox_member, inbox: inbox, user: user) } # rubocop:disable RSpec/LetSetup

    before { allow(AutoAssignment::AssignmentJob).to receive(:enqueue_for_inbox) }

    it 'kicks assignment for the agent inboxes when they transition to online' do
      mark_disconnected
      run_snapshot # records offline
      mark_present('online')
      run_snapshot # offline -> online transition

      expect(AutoAssignment::AssignmentJob).to have_received(:enqueue_for_inbox).with(inbox.id)
    end

    it 'does not kick assignment on the first-ever snapshot (no prior transition)' do
      mark_present('online')
      run_snapshot

      expect(AutoAssignment::AssignmentJob).not_to have_received(:enqueue_for_inbox)
    end

    it 'does not kick assignment when the agent goes offline' do
      mark_present('online')
      run_snapshot
      mark_disconnected
      run_snapshot

      expect(AutoAssignment::AssignmentJob).not_to have_received(:enqueue_for_inbox)
    end
  end

  describe 'offline-handoff trigger' do
    let(:handoff) { instance_double(AutoAssignment::OfflineReassignmentService, perform_for_agent: nil) }

    before { allow(AutoAssignment::OfflineReassignmentService).to receive(:new).and_return(handoff) }

    it 'hands off the agent conversations when they transition to offline' do
      mark_present('online')
      run_snapshot
      mark_disconnected
      run_snapshot # online -> offline transition

      expect(handoff).to have_received(:perform_for_agent).with(user.id)
    end

    it 'does not hand off on the first-ever snapshot (no prior transition)' do
      mark_disconnected
      run_snapshot

      expect(handoff).not_to have_received(:perform_for_agent)
    end

    it 'does not hand off when the agent comes online' do
      mark_disconnected
      run_snapshot
      mark_present('online')
      run_snapshot

      expect(handoff).not_to have_received(:perform_for_agent)
    end
  end
end
