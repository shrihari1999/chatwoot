require 'rails_helper'

RSpec.describe AgentBots::ScheduledConnectionJob do
  let!(:account) { create(:account) }
  let!(:agent_bot) { create(:agent_bot, account: account) }
  let!(:inbox) { create(:inbox, account: account) }

  def link_for(inbox)
    AgentBotInbox.find_by(inbox: inbox)
  end

  # A conversation the bot currently owns.
  def bot_conversation(status: :pending)
    create(:conversation, account: account, inbox: inbox, status: status, assignee_agent_bot: agent_bot)
  end

  it 'enqueues the job' do
    expect { described_class.perform_later('active') }
      .to have_enqueued_job(described_class).on_queue('scheduled_jobs')
  end

  it 'rejects a status the schedule should never send' do
    expect { described_class.perform_now('paused') }.to raise_error(ArgumentError, /paused/)
  end

  describe 'going on duty' do
    it 'connects the bot to an inbox that has none' do
      described_class.perform_now('active')

      expect(link_for(inbox)).to have_attributes(agent_bot_id: agent_bot.id, status: 'active')
    end

    it 'reactivates the link it was taken off duty with' do
      create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, status: :inactive)

      described_class.perform_now('active')

      expect(link_for(inbox).status).to eq('active')
    end

    it 'connects every inbox in the account' do
      other_inbox = create(:inbox, account: account)

      described_class.perform_now('active')

      expect(AgentBotInbox.where(inbox: [inbox, other_inbox]).pluck(:status)).to eq(%w[active active])
    end

    it 'leaves an already-connected inbox alone' do
      existing = create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, status: :active)

      described_class.perform_now('active')

      expect(link_for(inbox).id).to eq(existing.id)
    end
  end

  describe 'going off duty' do
    before { create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, status: :active) }

    it 'disconnects the inbox' do
      described_class.perform_now('inactive')

      expect(link_for(inbox).status).to eq('inactive')
    end

    it 'hands a conversation the bot was still working to the agents' do
      conversation = bot_conversation(status: :pending)

      described_class.perform_now('inactive')

      expect(conversation.reload).to have_attributes(status: 'open', assignee_agent_bot_id: nil)
    end

    it 'releases a conversation the bot already finished' do
      conversation = bot_conversation(status: :pending)
      conversation.resolved!
      # `resolved!` leaves ownership in place, which is precisely why it needs releasing.
      expect(conversation.reload.assignee_agent_bot_id).to eq(agent_bot.id)

      described_class.perform_now('inactive')

      expect(conversation.reload).to have_attributes(status: 'resolved', assignee_agent_bot_id: nil)
    end

    it 'leaves a conversation an agent has taken over alone' do
      agent = create(:user, account: account)
      conversation = create(:conversation, account: account, inbox: inbox, status: :open, assignee: agent)

      expect { described_class.perform_now('inactive') }
        .not_to(change { conversation.reload.updated_at })
    end

    it 'stops the bot being webhooked when the customer writes back' do
      conversation = bot_conversation(status: :pending)
      described_class.perform_now('inactive')

      message = create(:message, message_type: 'incoming', account: account, inbox: inbox,
                                 conversation: conversation.reload)

      expect(AgentBots::WebhookJob).not_to receive(:perform_later)
      # Loaded fresh: the listener reads the inbox through the message, and the `inbox`
      # this example built the link with still has the pre-job association cached.
      AgentBotListener.instance.message_created(
        Events::Base.new('message.created', Time.zone.now, message: Message.find(message.id))
      )
    end
  end

  describe 'when the account does not have exactly one bot' do
    it 'skips an account with more than one accessible bot' do
      create(:agent_bot, account: account)

      described_class.perform_now('active')

      expect(link_for(inbox)).to be_nil
    end

    it 'skips an account with no bot at all' do
      agent_bot.destroy!

      described_class.perform_now('active')

      expect(link_for(inbox)).to be_nil
    end

    it 'counts a system bot as accessible' do
      agent_bot.destroy!
      system_bot = create(:agent_bot, account: nil)

      described_class.perform_now('active')

      expect(link_for(inbox).agent_bot_id).to eq(system_bot.id)
    end
  end
end
