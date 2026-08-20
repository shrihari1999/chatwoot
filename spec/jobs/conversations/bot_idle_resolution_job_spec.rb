require 'rails_helper'

RSpec.describe Conversations::BotIdleResolutionJob do
  subject(:job) { described_class.perform_later }

  let!(:account) { create(:account) }
  let!(:bot_inbox) { create(:agent_bot_inbox, account: account) }
  let(:inbox) { bot_inbox.inbox }

  # A conversation the bot currently owns: pending, with the bot as assignee. `messages` are
  # created first and `last_activity_at` stamped afterwards, because creating a message
  # bumps that column to now and would lift the conversation back out of the idle window.
  def bot_conversation(last_activity_at:, messages: [])
    conversation = create(:conversation, account: account, inbox: inbox, status: :pending,
                                         assignee_agent_bot: bot_inbox.agent_bot)
    messages.each do |message_type|
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: message_type)
    end
    conversation.update!(last_activity_at: last_activity_at)
    conversation
  end

  it 'enqueues the job' do
    expect { job }.to have_enqueued_job(described_class).on_queue('scheduled_jobs')
  end

  it 'resolves a bot conversation the customer has gone quiet on' do
    conversation = bot_conversation(last_activity_at: 20.minutes.ago)

    described_class.perform_now

    expect(conversation.reload.status).to eq('resolved')
  end

  it 'credits the bot with the resolution, as an ordinary bot resolve would be' do
    conversation = bot_conversation(last_activity_at: 20.minutes.ago)

    # ReportingEventListener sits on the async dispatcher, so the events only
    # materialise once the enqueued EventDispatcherJob actually runs.
    perform_enqueued_jobs { described_class.perform_now }

    expect(account.reporting_events.where(name: 'conversation_bot_resolved', conversation_id: conversation.id)).to exist
  end

  it 'hands an unanswered customer message to an agent instead of burying it' do
    conversation = bot_conversation(last_activity_at: 20.minutes.ago, messages: [:incoming])

    described_class.perform_now

    expect(conversation.reload).to have_attributes(status: 'open', assignee_agent_bot_id: nil)
  end

  it 'records the handoff so it shows up as one in reports' do
    conversation = bot_conversation(last_activity_at: 20.minutes.ago, messages: [:incoming])

    perform_enqueued_jobs { described_class.perform_now }

    expect(account.reporting_events.where(name: 'conversation_bot_handoff', conversation_id: conversation.id)).to exist
  end

  it 'resolves when the bot answered and the customer went quiet' do
    conversation = bot_conversation(last_activity_at: 20.minutes.ago, messages: [:incoming, :outgoing])

    described_class.perform_now

    expect(conversation.reload.status).to eq('resolved')
  end

  # An SLA policy is attached a second after every first customer message. If activity
  # messages counted as a reply, every conversation would look answered and nothing would
  # ever reach an agent.
  it 'does not count an activity message as an answer' do
    conversation = bot_conversation(last_activity_at: 20.minutes.ago, messages: [:incoming, :activity])

    described_class.perform_now

    expect(conversation.reload.status).to eq('open')
  end

  it 'leaves a bot conversation that is still active' do
    conversation = bot_conversation(last_activity_at: 5.minutes.ago)

    described_class.perform_now

    expect(conversation.reload.status).to eq('pending')
  end

  # `determine_conversation_status` runs before_create and force-assigns the bot on a
  # bot-active inbox, so these states have to be set after the record exists.
  it 'leaves an idle conversation the bot no longer owns' do
    # What a handoff leaves behind: bot cleared, conversation open.
    conversation = bot_conversation(last_activity_at: 20.minutes.ago)
    conversation.update!(status: :open, assignee_agent_bot_id: nil)

    described_class.perform_now

    expect(conversation.reload.status).to eq('open')
  end

  it 'leaves an idle pending conversation that has no bot on it' do
    conversation = bot_conversation(last_activity_at: 20.minutes.ago)
    conversation.update!(assignee_agent_bot_id: nil)

    described_class.perform_now

    expect(conversation.reload.status).to eq('pending')
  end

  it 'resolves at most the bulk actions limit in one run' do
    create_list(:conversation, 3, account: account, inbox: inbox, status: :pending,
                                  assignee_agent_bot: bot_inbox.agent_bot, last_activity_at: 20.minutes.ago)
    stub_const('Limits::BULK_ACTIONS_LIMIT', 2)

    described_class.perform_now

    expect(Conversation.where(account: account, status: :pending).count).to eq(1)
  end
end
