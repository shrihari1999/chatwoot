# frozen_string_literal: true

module Instagram
  class ReactionService
    def initialize(params:, channel:)
      @params  = params
      @channel = channel
    end

    def perform
      reaction_data = @params[:reaction] || @params['reaction'] || {}
      mid       = reaction_data[:mid]    || reaction_data['mid']
      emoji     = reaction_data[:emoji]  || reaction_data['emoji']
      action    = reaction_data[:action] || reaction_data['action']
      sender    = @params[:sender] || @params['sender'] || {}
      sender_id = sender[:id] || sender['id']

      message = @channel.inbox.messages.find_by(source_id: mid)
      return unless message

      message.apply_reaction!(emoji: emoji, sender_id: sender_id, action: action)
    end
  end
end
