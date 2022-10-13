# frozen_string_literal: true

class AddSendEmailToPostPolicy < ActiveRecord::Migration[7.0]
  def change
    add_column :post_policies, :send_email, :boolean, default: false, null: false
  end
end
