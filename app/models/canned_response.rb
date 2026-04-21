# == Schema Information
#
# Table name: canned_responses
#
#  id         :integer          not null, primary key
#  content    :text
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

  validates :short_code, presence: true
  validates :account, presence: true
  validates :short_code, uniqueness: { scope: :account_id }
  validate :content_or_files_present
  validate :category_belongs_to_account, if: -> { category_id.present? }

  belongs_to :account
  belongs_to :category, class_name: 'CannedResponseCategory', optional: true
  has_many_attached :files

  def file_base_data
    files.map do |file|
      {
        id: file.id,
        canned_response_id: id,
        file_type: file.content_type,
        file_url: url_for(file),
        blob_id: file.blob_id,
        blob_signed_id: file.blob.signed_id,
        filename: file.filename.to_s
      }
    end
  end

  def as_json(options = {})
    super(options).merge(files: file_base_data)
  end

  scope :order_by_search, lambda { |search|
    short_code_starts_with = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 1', "#{search}%"])
    short_code_like = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 0.5', "%#{search}%"])
    content_like = sanitize_sql_array(['WHEN content ILIKE ? THEN 0.2', "%#{search}%"])

    order_clause = "CASE #{short_code_starts_with} #{short_code_like} #{content_like} ELSE 0 END"

    order(Arel.sql(order_clause) => :desc)
  }

  private

  def content_or_files_present
    return if content.present?
    return if files.attached?
    return if pending_file_ids.present?

    errors.add(:base, 'A canned response must have a message or at least one image attachment')
  end

  def category_belongs_to_account
    return if account && account.canned_response_categories.exists?(id: category_id)

    errors.add(:category, 'must belong to the same account')
  end
end
