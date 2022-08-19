class AddEmailSentToPolicyUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :policy_users, :email_sent, :date
  end
end
