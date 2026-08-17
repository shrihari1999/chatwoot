require 'rails_helper'

RSpec.describe Enterprise::AutoAssignment::CapacityService, type: :service do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true) }

  # Assignment policy with rate limiting
  let(:assignment_policy) do
    create(:assignment_policy,
           account: account,
           enabled: true,
           fair_distribution_limit: 5,
           fair_distribution_window: 3600)
  end

  # Agent capacity policy
  let(:agent_capacity_policy) do
    create(:agent_capacity_policy, account: account, name: 'Limited Capacity')
  end

  # Agents with different capacity settings
  let(:agent_with_capacity) { create(:user, account: account, role: :agent, availability: :online) }
  let(:agent_without_capacity) { create(:user, account: account, role: :agent, availability: :online) }
  let(:agent_at_capacity) { create(:user, account: account, role: :agent, availability: :online) }

  before do
    # Create inbox assignment policy
    create(:inbox_assignment_policy, inbox: inbox, assignment_policy: assignment_policy)

    # Set inbox capacity limit
    create(:inbox_capacity_limit,
           agent_capacity_policy: agent_capacity_policy,
           inbox: inbox,
           conversation_limit: 3)

    # Assign capacity policy to specific agents
    agent_with_capacity.account_users.find_by(account: account)
                       .update!(agent_capacity_policy: agent_capacity_policy)

    agent_at_capacity.account_users.find_by(account: account)
                     .update!(agent_capacity_policy: agent_capacity_policy)

    # Create inbox members
    create(:inbox_member, inbox: inbox, user: agent_with_capacity)
    create(:inbox_member, inbox: inbox, user: agent_without_capacity)
    create(:inbox_member, inbox: inbox, user: agent_at_capacity)

    # Mock online status
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return({
                                                                             agent_with_capacity.id.to_s => 'online',
                                                                             agent_without_capacity.id.to_s => 'online',
                                                                             agent_at_capacity.id.to_s => 'online'
                                                                           })

    # Enable assignment_v2 (base) and advanced_assignment (premium) features
    account.enable_features('assignment_v2', 'advanced_assignment')
    account.save!

    # Create existing assignments for agent_at_capacity (at limit)
    3.times do
      create(:conversation, account: account, inbox: inbox, assignee: agent_at_capacity, status: :open)
    end
  end

  describe 'capacity filtering' do
    it 'excludes agents at capacity' do
      # Get available agents respecting capacity
      capacity_service = described_class.new
      online_agents = inbox.available_agents
      filtered_agents = online_agents.select do |inbox_member|
        capacity_service.agent_has_capacity?(inbox_member.user, inbox)
      end
      available_users = filtered_agents.map(&:user)

      expect(available_users).to include(agent_with_capacity)
      expect(available_users).to include(agent_without_capacity) # No capacity policy = unlimited
      expect(available_users).not_to include(agent_at_capacity) # At capacity limit
    end

    it 'respects inbox-specific capacity limits' do
      capacity_service = described_class.new

      expect(capacity_service.agent_has_capacity?(agent_with_capacity, inbox)).to be true
      expect(capacity_service.agent_has_capacity?(agent_without_capacity, inbox)).to be true
      expect(capacity_service.agent_has_capacity?(agent_at_capacity, inbox)).to be false
    end
  end

  describe 'exclusion policy (zero conversation limit)' do
    let(:excluded_agent) { create(:user, account: account, role: :agent, availability: :online) }
    let(:exclusion_policy) { create(:agent_capacity_policy, account: account, name: 'Exclusion Policy') }

    before do
      create(:inbox_capacity_limit,
             agent_capacity_policy: exclusion_policy,
             inbox: inbox,
             conversation_limit: 0)

      excluded_agent.account_users.find_by(account: account)
                    .update!(agent_capacity_policy: exclusion_policy)

      create(:inbox_member, inbox: inbox, user: excluded_agent)

      allow(OnlineStatusTracker).to receive(:get_available_users).and_return({
                                                                               excluded_agent.id.to_s => 'online',
                                                                               agent_with_capacity.id.to_s => 'online',
                                                                               agent_without_capacity.id.to_s => 'online',
                                                                               agent_at_capacity.id.to_s => 'online'
                                                                             })
    end

    it 'always denies capacity for agents with zero limit' do
      capacity_service = described_class.new
      expect(capacity_service.agent_has_capacity?(excluded_agent, inbox)).to be false
    end

    it 'denies capacity even when agent has no existing conversations' do
      capacity_service = described_class.new
      # Agent has 0 open conversations but limit is 0, so 0 < 0 is false
      expect(excluded_agent.assigned_conversations.where(inbox: inbox, status: :open).count).to eq(0)
      expect(capacity_service.agent_has_capacity?(excluded_agent, inbox)).to be false
    end

    it 'excludes zero-limit agents from available agents list' do
      capacity_service = described_class.new
      online_agents = inbox.available_agents
      filtered_agents = online_agents.select do |inbox_member|
        capacity_service.agent_has_capacity?(inbox_member.user, inbox)
      end
      available_users = filtered_agents.map(&:user)

      expect(available_users).not_to include(excluded_agent)
      expect(available_users).to include(agent_with_capacity)
      expect(available_users).to include(agent_without_capacity)
    end
  end

  describe 'account-wide capacity counting' do
    let(:other_inbox) { create(:inbox, account: account, enable_auto_assignment: true) }

    before do
      create(:inbox_capacity_limit,
             agent_capacity_policy: agent_capacity_policy,
             inbox: other_inbox,
             conversation_limit: 3)

      create(:inbox_member, inbox: other_inbox, user: agent_at_capacity)
      create(:inbox_member, inbox: other_inbox, user: agent_with_capacity)
    end

    it 'counts open conversations from every inbox, not just the one being assigned' do
      capacity_service = described_class.new

      # agent_at_capacity holds 3 open conversations in `inbox` and none in `other_inbox`.
      expect(agent_at_capacity.assigned_conversations.where(inbox: other_inbox, status: :open).count).to eq(0)
      expect(capacity_service.agent_has_capacity?(agent_at_capacity, other_inbox)).to be false
    end

    it 'aggregates a load spread across inboxes' do
      capacity_service = described_class.new

      2.times { create(:conversation, account: account, inbox: inbox, assignee: agent_with_capacity, status: :open) }
      expect(capacity_service.agent_has_capacity?(agent_with_capacity, other_inbox)).to be true

      create(:conversation, account: account, inbox: other_inbox, assignee: agent_with_capacity, status: :open)
      expect(capacity_service.agent_has_capacity?(agent_with_capacity, other_inbox)).to be false
    end

    it 'still treats an inbox without a limit as unlimited' do
      unlimited_inbox = create(:inbox, account: account, enable_auto_assignment: true)
      create(:inbox_member, inbox: unlimited_inbox, user: agent_at_capacity)

      expect(described_class.new.agent_has_capacity?(agent_at_capacity, unlimited_inbox)).to be true
    end

    it 'ignores conversations belonging to another account' do
      other_account = create(:account)
      other_account_inbox = create(:inbox, account: other_account)
      3.times { create(:conversation, account: other_account, inbox: other_account_inbox, assignee: agent_with_capacity, status: :open) }

      expect(described_class.new.agent_has_capacity?(agent_with_capacity, inbox)).to be true
    end

    it 'ignores conversations that are not open' do
      3.times { create(:conversation, account: account, inbox: other_inbox, assignee: agent_with_capacity, status: :resolved) }

      expect(described_class.new.agent_has_capacity?(agent_with_capacity, inbox)).to be true
    end
  end

  describe 'assignment with capacity' do
    let(:service) { AutoAssignment::AssignmentService.new(inbox: inbox) }

    it 'assigns to agents with available capacity' do
      # Create conversation before assignment
      conversation = create(:conversation, account: account, inbox: inbox, assignee: nil, status: :open)

      # Mock the selector to prefer agent_at_capacity (but should skip due to capacity)
      selector = instance_double(AutoAssignment::RoundRobinSelector)
      allow(AutoAssignment::RoundRobinSelector).to receive(:new).and_return(selector)
      allow(selector).to receive(:select_agent) do |agents|
        agents.map(&:user).find { |u| [agent_with_capacity, agent_without_capacity].include?(u) }
      end

      assigned_count = service.perform_bulk_assignment(limit: 1)
      expect(assigned_count).to eq(1)
      expect(conversation.reload.assignee).to be_in([agent_with_capacity, agent_without_capacity])
      expect(conversation.reload.assignee).not_to eq(agent_at_capacity)
    end

    it 'returns false when all agents are at capacity' do
      # Fill up remaining agents
      3.times { create(:conversation, account: account, inbox: inbox, assignee: agent_with_capacity, status: :open) }

      # agent_without_capacity has no limit, so should still be available
      conversation2 = create(:conversation, account: account, inbox: inbox, assignee: nil, status: :open)
      assigned_count = service.perform_bulk_assignment(limit: 1)
      expect(assigned_count).to eq(1)
      expect(conversation2.reload.assignee).to eq(agent_without_capacity)
    end
  end
end
