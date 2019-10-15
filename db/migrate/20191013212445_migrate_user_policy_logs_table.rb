# frozen_string_literal: true

class MigrateUserPolicyLogsTable < ActiveRecord::Migration[6.0]
  def change
    create_table :user_policy_logs do |t|
      t.integer :post_policy_id, null: false
      t.integer :user_id, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at
      t.datetime :expired_at
      t.string :version
      t.timestamps null: false
    end

    add_index :user_policy_logs, %i[post_policy_id user_id]
  end
end
