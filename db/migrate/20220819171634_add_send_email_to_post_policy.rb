class AddSendEmailToPostPolicy < ActiveRecord::Migration[7.0]
  def change
    add_column :post_policies, :send_email, :boolean
  end
end
