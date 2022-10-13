# frozen_string_literal: true

class AddEmailedAtToPolicyUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :policy_users, :emailed_at, :datetime
  end
end
