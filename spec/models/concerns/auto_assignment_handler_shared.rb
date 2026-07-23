# frozen_string_literal: true

require 'rails_helper'

shared_examples_for 'auto_assignment_handler' do
  describe '#auto assignment' do
    let(:account) { create(:account) }
    let(:agent) { create(:user, email: 'agent1@example.com', account: account, auto_offline: false) }
    let(:inbox) { create(:inbox, account: account) }
    let(:conversation) do
      create(
        :conversation,
        account: account,
        contact: create(:contact, account: account),
        inbox: inbox,
        assignee: nil
      )
    end

    before do
      create(:inbox_member, inbox: inbox, user: agent)
      allow(Redis::Alfred).to receive(:rpoplpush).and_return(agent.id)
    end

    it 'runs round robin on after_save callbacks' do
      expect(conversation.reload.assignee).to eq(agent)
    end

    it 'will not auto assign agent if enable_auto_assignment is false' do
      inbox.update(enable_auto_assignment: false)

      expect(conversation.reload.assignee).to be_nil
    end

    it 'will not auto assign agent if its a bot conversation' do
      conversation = create(
        :conversation,
        account: account,
        contact: create(:contact, account: account),
        inbox: inbox,
        status: 'pending',
        assignee: nil
      )

      expect(conversation.reload.assignee).to be_nil
    end

    it 'enqueues the v2 assignment job only after the enclosing transaction commits' do
      # The job scans the inbox's unassigned conversations from another connection, so
      # enqueueing mid-transaction lets it run before this row is visible and the
      # conversation stays unassigned until the next trigger or the periodic sweep.
      account.enable_features('assignment_v2')
      step = nil
      enqueued_at = nil
      allow(AutoAssignment::AssignmentJob).to receive(:enqueue_for_inbox) { enqueued_at = step }

      ActiveRecord::Base.transaction do
        create(:conversation, account: account, contact: create(:contact, account: account), inbox: inbox, assignee: nil)
        step = :transaction_body_finished
      end

      expect(AutoAssignment::AssignmentJob).to have_received(:enqueue_for_inbox).with(inbox.id)
      expect(enqueued_at).to eq(:transaction_body_finished)
    end

    it 'gets triggered on update only when status changes to open' do
      conversation.status = 'resolved'
      conversation.save!
      expect(conversation.reload.assignee).to eq(agent)
      inbox.inbox_members.where(user_id: agent.id).first.destroy!

      # round robin changes assignee in this case since agent doesn't have access to inbox
      agent2 = create(:user, email: 'agent2@example.com', account: account, auto_offline: false)
      create(:inbox_member, inbox: inbox, user: agent2)
      allow(Redis::Alfred).to receive(:rpoplpush).and_return(agent2.id)
      conversation.status = 'open'
      conversation.save!
      expect(conversation.reload.assignee).to eq(agent2)
    end
  end
end
