module Enterprise::UserPolicy
  def create?
    @account_user.custom_role&.permissions&.include?('settings_manage') || super
  end

  def update?
    @account_user.custom_role&.permissions&.include?('settings_manage') || super
  end

  def destroy?
    @account_user.custom_role&.permissions&.include?('settings_manage') || super
  end

  def bulk_create?
    @account_user.custom_role&.permissions&.include?('settings_manage') || super
  end
end
