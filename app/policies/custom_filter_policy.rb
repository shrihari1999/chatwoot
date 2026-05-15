class CustomFilterPolicy < ApplicationPolicy
  def index?
    @account_user.administrator? || @account_user.agent?
  end

  def show?
    @account_user.administrator? || @account_user.agent?
  end

  def create?
    return manager_or_above? if shared_record?

    @account_user.administrator? || @account_user.agent?
  end

  def update?
    return manager_or_above? if shared_record?

    owner?
  end

  def destroy?
    return manager_or_above? if shared_record?

    owner?
  end

  private

  def shared_record?
    record.is_a?(CustomFilter) && record.shared
  end

  def owner?
    record.is_a?(CustomFilter) && record.user_id == @user.id
  end

  def manager_or_above?
    @account_user.administrator? || @account_user.custom_role_id.present?
  end
end
