class SuperAdmin::AccountsController < SuperAdmin::ApplicationController
  # Overwrite any of the RESTful controller actions to implement custom behavior
  # For example, you may want to send an email after a foo is updated.
  #
  # def update
  #   super
  #   send_foo_updated_email(requested_resource)
  # end

  # Override this method to specify custom lookup behavior.
  # This will be used to set the resource for the `show`, `edit`, and `update`
  # actions.
  #
  # def find_resource(param)
  #   Foo.find_by!(slug: param)
  # end

  # The result of this lookup will be available as `requested_resource`

  # Override this if you have certain roles that require a subset
  # this will be used to set the records shown on the `index` action.
  #
  # def scoped_resource
  #   if current_user.super_admin?
  #     resource_class
  #   else
  #     resource_class.with_less_stuff
  #   end
  # end

  # Override `resource_params` if you want to transform the submitted
  # data before it's persisted. For example, the following would turn all
  # empty values into nil values. It uses other APIs such as `resource_class`
  # and `dashboard`:
  #
  def update
    assign_feature_flag_selection(requested_resource) if params[:enabled_features].present?
    super
  end

  def resource_params
    permitted_params = super
    permitted_params[:limits] = permitted_params[:limits].to_h.compact
    permitted_params
  end

  # See https://administrate-prototype.herokuapp.com/customizing_controller_actions
  # for more information

  def seed
    Internal::SeedAccountJob.perform_later(requested_resource)
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Account seeding triggered')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def reset_cache
    requested_resource.reset_cache_keys
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Cache keys cleared')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def destroy
    account = Account.find(params[:id])

    DeleteObjectJob.perform_later(account) if account.present?
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Account deletion is in progress.')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  private

  # Feature flags now span multiple bigint columns (see Featurable). Route the
  # checked flags to each column's flag_shih_tzu bulk setter (selected_<column>=),
  # which clears that column and enables only the checked flags. The extended
  # column(s) are assigned FIRST so the enterprise `selected_feature_flags=`
  # override (which runs sync_assignment_features) executes LAST and wins —
  # exactly as it did when all flags lived in a single column.
  def assign_feature_flag_selection(account)
    selected = params[:enabled_features].keys.map(&:to_sym)
    extended_columns = Account.flag_mapping.keys - ['feature_flags']
    extended_columns.each do |column|
      account.public_send("selected_#{column}=", selected & Account.flag_mapping[column].keys)
    end
    account.selected_feature_flags = selected & Account.flag_mapping['feature_flags'].keys
  end
end

SuperAdmin::AccountsController.prepend_mod_with('SuperAdmin::AccountsController')
