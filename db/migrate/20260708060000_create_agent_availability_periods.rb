class CreateAgentAvailabilityPeriods < ActiveRecord::Migration[7.1]
  def change
    create_table :agent_availability_periods do |t|
      t.bigint :account_id, null: false
      t.bigint :user_id, null: false
      # 0: online, 1: busy, 2: offline (see AgentAvailabilityPeriod)
      t.integer :status, null: false, default: 2
      t.datetime :started_at, null: false
      t.datetime :ended_at

      t.timestamps
    end

    add_index :agent_availability_periods, %i[account_id user_id started_at],
              name: 'idx_agent_availability_on_account_user_started'
    # Fast lookup of the single currently-open period per agent.
    add_index :agent_availability_periods, %i[account_id user_id],
              where: 'ended_at IS NULL', unique: true,
              name: 'idx_agent_availability_open_period'
  end
end
