class SlaPolicyPolicy < ApplicationPolicy
  def index?
    @account_user.administrator? || @account_user.agent?
  end

  def update?
    @account_user.administrator? || settings_manager?
  end

  def show?
    @account_user.administrator? || @account_user.agent?
  end

  def create?
    @account_user.administrator? || settings_manager?
  end

  def destroy?
    @account_user.administrator? || settings_manager?
  end

  private

  def settings_manager?
    @account_user.custom_role&.permissions&.include?('settings_manage')
  end
end
