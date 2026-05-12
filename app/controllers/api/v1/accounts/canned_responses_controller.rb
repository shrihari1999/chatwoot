class Api::V1::Accounts::CannedResponsesController < Api::V1::Accounts::BaseController
  before_action :fetch_canned_response, only: [:update, :destroy]

  def index
    render json: canned_responses.map { |cr| serialize(cr) }
  end

  def create
    ActiveRecord::Base.transaction do
      @canned_response = Current.account.canned_responses.new(canned_response_params)
      @canned_response.pending_file_ids = file_blob_ids
      @canned_response.save!
      attach_files
    end
    render json: serialize(@canned_response)
  end

  def update
    ActiveRecord::Base.transaction do
      @canned_response.pending_file_ids = file_blob_ids
      @canned_response.update!(canned_response_params)
      update_files
      # Re-validate after file changes — guards against clearing both content and files
      raise ActiveRecord::RecordInvalid.new(@canned_response) unless @canned_response.valid?
    end
    @canned_response.reload
    render json: serialize(@canned_response)
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

  def serialize(canned_response)
    canned_response.as_json.merge(
      category: canned_response.category&.as_json(only: [:id, :name])
    )
  end

  def file_blob_ids
    Array(params[:file_ids])
  end

  def attach_files
    return if file_blob_ids.blank?

    blobs = file_blob_ids.map do |signed_id|
      ActiveStorage::Blob.find_signed!(signed_id)
    rescue ActiveRecord::RecordNotFound, ActiveSupport::MessageVerifier::InvalidSignature
      @canned_response.errors.add(:files, 'contains an invalid attachment reference')
      raise ActiveRecord::RecordInvalid, @canned_response
    end
    @canned_response.files.attach(blobs)
  end

  # Note: `file_ids: []` is meaningful — it explicitly clears attachments. We distinguish
  # "key absent" (leave files untouched) from "empty array" (detach all) via params.key?.
  def update_files
    return unless params.key?(:file_ids)

    @canned_response.files.detach
    attach_files
  end

  def canned_responses
    scope = if params[:search]
              Current.account.canned_responses.with_attached_files
                     .where('short_code ILIKE :search', search: "%#{params[:search]}%")
                     .order_by_search(params[:search])
            else
              Current.account.canned_responses.with_attached_files
            end
    scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
    scope
  end
end
