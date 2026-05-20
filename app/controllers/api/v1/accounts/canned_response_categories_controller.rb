# frozen_string_literal: true

class Api::V1::Accounts::CannedResponseCategoriesController < Api::V1::Accounts::BaseController
  before_action :set_category, only: [:update, :destroy]

  def index
    @categories = Current.account.canned_response_categories.order(:name)
    render json: @categories.map { |category| serialize(category) }
  end

  def create
    @category = Current.account.canned_response_categories.new(category_params)
    assign_owner
    if @category.save
      render json: serialize(@category), status: :created
    else
      render json: { errors: @category.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    @category.assign_attributes(category_params)
    assign_owner
    if @category.save
      render json: serialize(@category)
    else
      render json: { errors: @category.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    if @category.destroy
      head :ok
    else
      # `dependent: :restrict_with_error` blocks deletion when the category still
      # has canned responses; surface that as a 422 with the model's error message.
      render json: { errors: @category.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_category
    @category = Current.account.canned_response_categories.find(params[:id])
  end

  # `only_me` categories must have an owner. Fill it from the current user when
  # missing (create, or an existing category switched to `only_me`); the model
  # clears user_id again for any other visibility.
  def assign_owner
    @category.user ||= Current.user
  end

  def category_params
    params.permit(:name, :visibility, :team_id)
  end

  def serialize(category)
    category.as_json(only: [:id, :name, :visibility, :user_id, :team_id])
            .merge(team: category.team&.as_json(only: [:id, :name]))
  end
end
