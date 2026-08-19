# == Schema Information
#
# Table name: canned_responses
#
#  id         :integer          not null, primary key
#  content    :text
#  content_variants :jsonb           not null
#  content_variant_cursor :integer   default(0), not null
#  short_code :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :integer          not null
#

class CannedResponse < ApplicationRecord
  include Rails.application.routes.url_helpers

  # Transient attribute set by the controller before `save` on create, carrying the
  # Active Storage signed blob IDs of files that will be attached after the record is
  # persisted. Read by `content_or_files_present` so image-only responses pass validation
  # before the attachments physically exist on the record.
  attr_accessor :pending_file_ids

  # Alternative wordings of the same message. Instagram penalises an account that
  # sends byte-identical text repeatedly, so the composer cycles through these
  # instead of always inserting `content`. Four wordings total is what the UI renders.
  CONTENT_VARIANTS_LIMIT = 3

  validates :short_code, presence: true
  validates :account, presence: true
  validates :short_code, uniqueness: { scope: :account_id }
  validate :content_or_files_present
  validate :category_belongs_to_account, if: -> { category_id.present? }
  validate :ensure_valid_content_variants

  belongs_to :account
  belongs_to :category, class_name: 'CannedResponseCategory'
  has_many_attached :files

  # Longest edge of the preview variant. Every consumer of these URLs renders at
  # 32-40px (picker, settings list, edit form, composer thumb), so 96px covers 3x DPI.
  THUMB_DIMENSION = 96

  def file_base_data
    files.map do |file|
      {
        id: file.id,
        canned_response_id: id,
        file_type: file.content_type,
        file_url: url_for(file),
        thumb_url: thumb_url_for(file),
        blob_id: file.blob_id,
        blob_signed_id: file.blob.signed_id,
        filename: file.filename.to_s
      }
    end
  end

  def as_json(options = {})
    super(options).merge(files: file_base_data)
  end

  # Every wording this response may insert, in cycle order. The attachments are
  # shared across all of them -- only the text varies.
  def contents
    [content, *content_variants].compact_blank
  end

  # Moves the cursor on to the next wording and returns its index. The composer has
  # already inserted the wording at the previous index, so this only records that it
  # was used. update_column keeps this out of the record's updated_at/callbacks --
  # it is bookkeeping, not an edit to the canned response.
  def advance_content_variant!
    return 0 if contents.size <= 1

    with_lock do
      next_index = (content_variant_cursor + 1) % contents.size
      update_column(:content_variant_cursor, next_index) # rubocop:disable Rails/SkipsModelValidations
      next_index
    end
  end

  scope :order_by_search, lambda { |search|
    short_code_starts_with = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 1', "#{search}%"])
    short_code_like = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 0.5', "%#{search}%"])

    order_clause = "CASE #{short_code_starts_with} #{short_code_like} ELSE 0 END"

    order(Arel.sql(order_clause) => :desc)
  }

  private

  # Only the URL is built here — Active Storage generates the variant lazily on first
  # request, so serialisation stays cheap. Non-representable attachments (a PDF, say)
  # fall back to the original.
  def thumb_url_for(file)
    return url_for(file) unless file.representable?

    url_for(file.representation(resize_to_limit: [THUMB_DIMENSION, THUMB_DIMENSION]))
  end

  def content_or_files_present
    return if content.present?
    return if files.attached?
    return if pending_file_ids.present?

    errors.add(:base, 'A canned response must have a message or at least one image attachment')
  end

  def ensure_valid_content_variants
    return if content_variants.blank?

    unless content_variants.is_a?(Array) && content_variants.all?(String)
      errors.add(:content_variants, 'must be a list of messages')
      return
    end

    return unless content_variants.size > CONTENT_VARIANTS_LIMIT

    errors.add(:content_variants, "cannot hold more than #{CONTENT_VARIANTS_LIMIT} messages")
  end

  def category_belongs_to_account
    return if account && account.canned_response_categories.exists?(id: category_id)

    errors.add(:category, 'must belong to the same account')
  end
end
