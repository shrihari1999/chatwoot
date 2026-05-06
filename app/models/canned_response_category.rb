# frozen_string_literal: true

class CannedResponseCategory < ApplicationRecord
  belongs_to :account
  has_many :canned_responses, foreign_key: :category_id, dependent: :restrict_with_error, inverse_of: :category

  validates :name, presence: true
  validates :name, uniqueness: { scope: :account_id }
end
