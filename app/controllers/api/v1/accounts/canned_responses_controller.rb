class Api::V1::Accounts::CannedResponsesController < Api::V1::Accounts::BaseController
  before_action :fetch_canned_response, only: [:update, :destroy]

  def index
    render json: canned_responses.map { |cr|
      cr.as_json.merge(
        category: cr.category ? cr.category.as_json(only: [:id, :name]) : nil
      )
    }
  end

  def create
    @canned_response = Current.account.canned_responses.new(canned_response_params)
    @canned_response.save!
    attach_files
    render json: @canned_response.as_json.merge(
      category: @canned_response.category ? @canned_response.category.as_json(only: [:id, :name]) : nil
    )
  end

  def update
    @canned_response.update!(canned_response_params)
    update_files
    @canned_response.reload
    render json: @canned_response.as_json.merge(
      category: @canned_response.category ? @canned_response.category.as_json(only: [:id, :name]) : nil
    )
  end

  def destroy
    @canned_response.destroy!
    head :ok
  end

  private

  def fetch_canned_response
    @canned_response = Current.account.canned_responses.find(params[:id])
  end

  def canned_response_params
    params.require(:canned_response).permit(:short_code, :content, :category_id)
  end

  def file_blob_ids
    params[:file_ids]
  end

  def attach_files
    return if file_blob_ids.blank?

    blobs = file_blob_ids.map { |signed_id| ActiveStorage::Blob.find_signed!(signed_id) }
    @canned_response.files.attach(blobs)
  end

  def update_files
    return unless params.key?(:file_ids)

    @canned_response.files.detach
    attach_files
  end

  def canned_responses
    scope = if params[:search]
              Current.account.canned_responses.with_attached_files
                     .where('short_code ILIKE :search OR content ILIKE :search', search: "%#{params[:search]}%")
                     .order_by_search(params[:search])
            else
              Current.account.canned_responses.with_attached_files
            end
    scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
    scope
  end
end
