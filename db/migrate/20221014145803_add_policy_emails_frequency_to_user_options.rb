class AddPolicyEmailsFrequencyToUserOptions < ActiveRecord::Migration[7.0]
  def change
    add_column :user_options, :policy_email_frequency, :integer, default: 0, null: false
  end
end
