module Enterprise::InboxPolicy
  def update?
    @account_user.custom_role&.permissions&.include?('settings_manage') || super
  end

  def avatar?
    @account_user.custom_role&.permissions&.include?('settings_manage') || super
  end

  def sync_templates?
    @account_user.custom_role&.permissions&.include?('settings_manage') || super
  end

  def set_agent_bot?
    @account_user.custom_role&.permissions&.include?('settings_manage') || super
  end

  def health?
    @account_user.custom_role&.permissions&.include?('settings_manage') || super
  end

  def reset_secret?
    @account_user.custom_role&.permissions&.include?('settings_manage') || super
  end
end
