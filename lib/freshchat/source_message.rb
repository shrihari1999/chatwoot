class Freshchat::SourceMessage < Freshchat::SourceBase
  self.table_name = 'home_freshchatconversationmessage'
  self.primary_key = 'id'

  def readonly?
    true
  end
end
