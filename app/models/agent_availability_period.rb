# == Schema Information
#
# Table name: agent_availability_periods
#
#  id         :bigint           not null, primary key
#  ended_at   :datetime
#  started_at :datetime         not null
#  status     :integer          default("offline"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  idx_agent_availability_on_account_user_started  (account_id,user_id,started_at)
#  idx_agent_availability_open_period              (account_id,user_id) UNIQUE WHERE (ended_at IS NULL)
#

# A durable, edge-logged history of each agent's effective availability
# (online/busy/offline) over time. Written by AgentAvailabilitySnapshotJob once a
# minute — one row per continuous stretch of a status, so intervals and break
# durations are read directly. This is the persistent counterpart to the
# ephemeral Redis presence heartbeat, which is thrown away after ~20s.
class AgentAvailabilityPeriod < ApplicationRecord
  belongs_to :account
  belongs_to :user

  # Keys intentionally match the strings returned by AvailabilityStatusable#availability_status.
  enum status: { online: 0, busy: 1, offline: 2 }

  validates :started_at, presence: true

  # The single currently-open period for an agent (nil ended_at).
  scope :open, -> { where(ended_at: nil) }
  # Periods that overlap the [from, to) window.
  scope :overlapping, lambda { |from, to|
    where('started_at < ? AND (ended_at IS NULL OR ended_at > ?)', to, from)
  }
end
