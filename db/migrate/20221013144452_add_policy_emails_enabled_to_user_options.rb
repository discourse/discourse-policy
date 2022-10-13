class AddPolicyEmailsEnabledToUserOptions < ActiveRecord::Migration[7.0]
  def change
    add_column :user_options, :policy_emails_enabled, :boolean, default: false, null: false
  end
end
