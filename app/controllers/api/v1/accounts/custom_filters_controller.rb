class Api::V1::Accounts::CustomFiltersController < Api::V1::Accounts::BaseController
  before_action :check_authorization, only: [:index]
  before_action :fetch_custom_filters, only: [:index]
  before_action :fetch_custom_filter, only: [:show, :update, :destroy]
  before_action :validate_query_timezones, only: [:create, :update]
  DEFAULT_FILTER_TYPE = 'conversation'.freeze

  def index; end

  def show; end

  def create
    @custom_filter = Current.account.custom_filters.new(permitted_payload.merge(user: Current.user))
    authorize(@custom_filter)
    @custom_filter.save!
    render json: { error: @custom_filter.errors.messages }, status: :unprocessable_entity and return unless @custom_filter.valid?
  end

  def update
    @custom_filter.assign_attributes(permitted_payload)
    authorize(@custom_filter)
    @custom_filter.save!
  end

  def destroy
    @custom_filter.destroy!
    head :no_content
  end

  private

  def fetch_custom_filters
    filter_type = permitted_params[:filter_type] || DEFAULT_FILTER_TYPE
    @custom_filters = Current.account.custom_filters
                             .where(filter_type: filter_type)
                             .where('user_id = ? OR shared = ?', Current.user.id, true)
  end

  def fetch_custom_filter
    @custom_filter = Current.account.custom_filters.find(permitted_params[:id])
    authorize(@custom_filter)
  end

  def permitted_payload
    params.require(:custom_filter).permit(
      :name,
      :filter_type,
      :shared,
      query: {}
    )
  end

  def validate_query_timezones
    query = permitted_payload.fetch(:query, {})
    return unless query.key?(:payload)

    payload = query[:payload]
    unless payload.is_a?(Array) && payload.all?(ActionController::Parameters)
      raise CustomExceptions::CustomFilter::InvalidValue.new(attribute_name: 'payload')
    end

    payload.each do |condition|
      ::Filters::DateFilterHelper.timezone(condition[:timezone]) if condition.key?(:timezone)
    end
  rescue CustomExceptions::CustomFilter::InvalidValue => e
    render_could_not_create_error(e.message)
  end

  def permitted_params
    params.permit(:id, :filter_type)
  end
end
