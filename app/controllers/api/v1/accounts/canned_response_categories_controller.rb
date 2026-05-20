# frozen_string_literal: true

class Api::V1::Accounts::CannedResponseCategoriesController < Api::V1::Accounts::BaseController
  before_action :set_category, only: [:update, :destroy]

  def index
    @categories = Current.account.canned_response_categories.order(:name)
    render json: @categories.map { |category| serialize(category) }
  end

  def create
    @category = Current.account.canned_response_categories.new(category_params)
    # The creating agent owns the category; the model keeps user_id only for `only_me`.
    @category.user = Current.user
    if @category.save
      render json: serialize(@category), status: :created
    else
      render json: { errors: @category.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @category.update(category_params)
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

  def category_params
    params.permit(:name, :visibility, :team_id)
  end

  def serialize(category)
    category.as_json(only: [:id, :name, :visibility, :user_id, :team_id])
            .merge(team: category.team&.as_json(only: [:id, :name]))
  end
end
