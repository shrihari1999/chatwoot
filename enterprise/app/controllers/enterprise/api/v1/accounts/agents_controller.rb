module Enterprise::Api::V1::Accounts::AgentsController
  def create
    forbid_non_admin_assigning_administrator!
    super
    return if @agent.blank?

    associate_agent_with_custom_role
  end

  def update
    forbid_non_admin_acting_on_administrator!
    forbid_non_admin_assigning_administrator!
    super
    associate_agent_with_custom_role
  end

  def destroy
    forbid_non_admin_acting_on_administrator!
    super
  end

  private

  def forbid_non_admin_assigning_administrator!
    return if Current.account_user.administrator?

    requested_role = params.dig(:agent, :role) || params[:role]
    raise Pundit::NotAuthorizedError if requested_role.to_s == 'administrator'
  end

  def forbid_non_admin_acting_on_administrator!
    return if Current.account_user.administrator?
    return if @agent.nil?

    target_account_user = @agent.account_users.find_by(account: Current.account)
    raise Pundit::NotAuthorizedError if target_account_user&.administrator?
  end

  def associate_agent_with_custom_role
    # Custom roles are a premium feature; block assigning one when the feature is disabled,
    # but still allow clearing a stale custom_role_id left over from before a downgrade.
    return if params[:custom_role_id].present? && !Current.account.feature_enabled?('custom_roles')

    @agent.current_account_user.update!(custom_role_id: params[:custom_role_id])
  end
end
