class Api::V1::Accounts::CannedResponsesController < Api::V1::Accounts::BaseController
  # Mirrors MailboxSanitizer::NULL_BYTE. Defined locally rather than reaching into a
  # mailbox module from a canned-response controller.
  NULL_BYTE = "\u0000".freeze

  before_action :fetch_canned_response, only: [:update, :destroy, :advance_variant]

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

  # Records that the composer just used the wording at the current cursor, so the next
  # insertion -- by this agent or any other -- gets the following one. Fire-and-forget
  # from the picker: the text is already in the composer by the time this runs.
  def advance_variant
    render json: { content_variant_cursor: @canned_response.advance_content_variant! }
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
    params.require(:canned_response).permit(:short_code, :content, :category_id, content_variants: [])
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
    # `includes(:category)` — `serialize` reads `category` on every row, so without it
    # the index is 1 + N queries. The `visible` branch below joins the same association,
    # but a join filters without preloading, so the preload is still required.
    scope = search_scope.includes(:category)
    scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
    # `visible` is passed by the conversation canned-response picker so that categories
    # restricted to other users / other teams are filtered out. The settings page omits
    # it and continues to see every canned response.
    scope = scope.joins(:category).merge(CannedResponseCategory.visible_to(Current.user)) if params[:visible].present?
    scope
  end

  def search_scope
    # Blank-check the *sanitised* term, not the raw param: a search made up entirely of
    # NUL bytes would otherwise become "%%" and hit `order_by_search('')`. After
    # stripping it correctly degrades to "no search term".
    search = sanitized_search
    return Current.account.canned_responses.with_attached_files if search.blank?

    Current.account.canned_responses.with_attached_files
           .where('short_code ILIKE :search', search: "%#{search}%")
           .order_by_search(search)
  end

  # Postgres rejects NUL bytes in query parameters with
  # `ArgumentError: string contains null byte`, so a pasted "\u0000" 500s this endpoint.
  # Agents hit this in production by pasting into the conversation canned-response picker
  # (observed term: NUL + an emoji). Both consumers below need it stripped -- the ILIKE
  # bind param, and `order_by_search`, whose `sanitize_sql_array` escapes SQL but does
  # not remove NUL.
  #
  # Strips rather than 400s, matching MailboxSanitizer's handling of inbound email --
  # including its `is_a?(String)` guard. `?search[]=x` yields an Array and `?search[a]=b`
  # yields ActionController::Parameters; on those, `delete` means delete-by-key, not
  # delete-characters. Non-strings are passed through untouched so they keep behaving
  # exactly as they did before this fix.
  def sanitized_search
    value = params[:search]
    return value unless value.is_a?(String)

    value.delete(NULL_BYTE)
  end
end
