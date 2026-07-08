require 'rails_helper'

RSpec.describe AutoAssignment::OfflineReassignmentService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true) }
  let(:policy) { create(:assignment_policy, account: account) }
  let(:offline_agent) { create(:user) }
  let(:online_agent) { create(:user) }

  before do
    account.enable_features!('assignment_v2')
    create(:inbox_assignment_policy, inbox: inbox, assignment_policy: policy)
    [offline_agent, online_agent].each do |u|
      create(:account_user, account: account, user: u, role: :agent)
      create(:inbox_member, inbox: inbox, user: u)
    end
    # online_agent has a live heartbeat; offline_agent has none.
    OnlineStatusTracker.update_presence(account.id, 'AccountUser', online_agent.id)
    OnlineStatusTracker.set_status(account.id, online_agent.id, 'online')
    allow(AutoAssignment::AssignmentJob).to receive(:enqueue_for_inbox)
  end

  def conversation_for(agent, **attrs)
    create(:conversation, account: account, inbox: inbox, assignee: agent, status: :open, **attrs)
  end

  describe '#perform' do
    it 'unassigns a conversation stranded on an offline agent and kicks assignment' do
      conversation = conversation_for(offline_agent)

      expect { described_class.new(account: account).perform }
        .to change { conversation.reload.assignee_id }.from(offline_agent.id).to(nil)
      expect(AutoAssignment::AssignmentJob).to have_received(:enqueue_for_inbox).with(inbox.id)
    end

    it 'leaves a conversation assigned to an online agent alone' do
      conversation = conversation_for(online_agent)

      expect { described_class.new(account: account).perform }
        .not_to(change { conversation.reload.assignee_id })
      expect(AutoAssignment::AssignmentJob).not_to have_received(:enqueue_for_inbox)
    end

    it 'leaves a busy agent conversations alone (busy is still present)' do
      OnlineStatusTracker.set_status(account.id, offline_agent.id, 'busy')
      OnlineStatusTracker.update_presence(account.id, 'AccountUser', offline_agent.id)
      conversation = conversation_for(offline_agent)

      expect { described_class.new(account: account).perform }
        .not_to(change { conversation.reload.assignee_id })
    end

    it 'ignores resolved conversations' do
      conversation = conversation_for(offline_agent, status: :resolved)

      expect { described_class.new(account: account).perform }
        .not_to(change { conversation.reload.assignee_id })
    end

    it 'ignores inboxes without auto-assignment / a policy' do
      plain_inbox = create(:inbox, account: account, enable_auto_assignment: false)
      create(:inbox_member, inbox: plain_inbox, user: offline_agent)
      conversation = create(:conversation, account: account, inbox: plain_inbox, assignee: offline_agent, status: :open)

      expect { described_class.new(account: account).perform }
        .not_to(change { conversation.reload.assignee_id })
    end

    it 'is a no-op when assignment_v2 is disabled' do
      account.disable_features!('assignment_v2')
      conversation = conversation_for(offline_agent)

      expect { described_class.new(account: account).perform }
        .not_to(change { conversation.reload.assignee_id })
    end
  end

  describe '#perform_for_agent' do
    it 'only touches the given offline agent conversations' do
      other_offline = create(:user)
      create(:account_user, account: account, user: other_offline, role: :agent)
      create(:inbox_member, inbox: inbox, user: other_offline)
      mine = conversation_for(offline_agent)
      theirs = conversation_for(other_offline)

      described_class.new(account: account).perform_for_agent(offline_agent.id)

      expect(mine.reload.assignee_id).to be_nil
      expect(theirs.reload.assignee_id).to eq(other_offline.id)
    end
  end
end
