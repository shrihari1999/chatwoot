class CustomRolePolicy < ApplicationPolicy
  def index?
    @account_user.administrator? || settings_manager?
  end

  def update?
    @account_user.administrator?
  end

  def show?
    @account_user.administrator? || settings_manager?
  end

  def create?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  private

  def settings_manager?
    @account_user.custom_role&.permissions&.include?('settings_manage')
  end
end
