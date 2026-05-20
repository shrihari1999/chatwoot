# frozen_string_literal: true

class CannedResponseCategory < ApplicationRecord
  belongs_to :account
  belongs_to :user, optional: true
  belongs_to :team, optional: true
  has_many :canned_responses, foreign_key: :category_id, dependent: :restrict_with_error, inverse_of: :category

  # Controls who sees this category's canned responses in the conversation picker.
  enum visibility: { everyone: 0, only_me: 1, specific_team: 2 }

  before_validation :clear_unused_scope

  validates :name, presence: true
  validates :name, uniqueness: { scope: :account_id }
  validates :user_id, presence: true, if: :only_me?
  validates :team_id, presence: true, if: :specific_team?

  # Categories the given user is allowed to see in the conversation canned-response picker.
  scope :visible_to, lambda { |user|
    everyone
      .or(only_me.where(user_id: user.id))
      .or(specific_team.where(team_id: user.team_ids))
  }

  private

  # A category only carries the scope field relevant to its visibility — clear the rest
  # so a category switched to "all agents" does not keep a stale owner/team reference.
  def clear_unused_scope
    self.user_id = nil unless only_me?
    self.team_id = nil unless specific_team?
  end
end
