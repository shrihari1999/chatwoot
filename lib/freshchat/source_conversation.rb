class Freshchat::SourceConversation < Freshchat::SourceBase
  self.table_name = 'home_freshchatconversation'
  self.primary_key = 'id'

  def readonly?
    true
  end
end
