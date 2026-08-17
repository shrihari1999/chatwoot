# Puts the account's agent bot on and off duty on a fixed daily schedule, so it only
# answers customers during shop hours.
#
# Chatwoot has no notion of bot working hours, and "disconnect the bot" is not enough on
# its own: `agent_bot_inbox` only decides which bot picks up *new* conversations, while
# `conversation.assignee_agent_bot` is live ownership of *this* conversation and keeps
# receiving webhooks regardless of the inbox link (AgentBotListener#agent_bots_for reads
# both sources). That ownership also survives `resolved!` — exactly like a human
# assignee — so a conversation the bot answered this afternoon would wake it again when
# the customer writes back at midnight.
#
# Taking the bot off duty therefore means both halves: flip the inbox links, then release
# every conversation the bot still owns.
class AgentBots::ScheduledConnectionJob < ApplicationJob
  queue_as :scheduled_jobs

  # `status` comes from config/schedule.yml: 'active' in the morning, 'inactive' at night.
  def perform(status)
    status = status.to_s
    raise ArgumentError, "expected an AgentBotInbox status, got #{status.inspect}" unless AgentBotInbox.statuses.key?(status)

    Account.find_each do |account|
      agent_bot = sole_accessible_bot(account)
      next if agent_bot.blank?

      status == 'active' ? put_on_duty(account, agent_bot) : take_off_duty(account, agent_bot)
    end
  end

  private

  # The schedule is a blunt instrument: it can only mean "the bot" while there is exactly
  # one to mean. With two, picking one would be a guess, so leave the account untouched
  # and say so rather than silently attaching the wrong bot to every inbox.
  def sole_accessible_bot(account)
    agent_bots = AgentBot.accessible_to(account).to_a
    return agent_bots.first if agent_bots.one?

    Rails.logger.info(
      "[AgentBots::ScheduledConnectionJob] skipping account #{account.id}: expected 1 accessible bot, found #{agent_bots.size}"
    )
    nil
  end

  def put_on_duty(account, agent_bot)
    account.inboxes.find_each do |inbox|
      agent_bot_inbox = inbox.agent_bot_inbox || AgentBotInbox.new(inbox: inbox)
      agent_bot_inbox.agent_bot = agent_bot
      agent_bot_inbox.status = :active
      agent_bot_inbox.save!
    end
  end

  def take_off_duty(account, agent_bot)
    # Links first: releasing a conversation dispatches events of its own, and an inactive
    # link is what stops those events reaching the bot on the way out.
    account.agent_bot_inboxes.where(agent_bot: agent_bot).find_each(&:inactive!)
    release_owned_conversations(account, agent_bot)
  end

  # A pending conversation is one the bot was still working, so it goes through the
  # regular handoff and lands in the agents' queue instead of being auto-resolved
  # unanswered. Everything else it owns is already finished, and only needs the
  # ownership pointer cleared so a customer replying overnight reaches a human.
  def release_owned_conversations(account, agent_bot)
    account.conversations.where(assignee_agent_bot_id: agent_bot.id).find_each do |conversation|
      conversation.pending? ? conversation.bot_handoff! : conversation.update!(assignee_agent_bot_id: nil)
    end
  end
end
