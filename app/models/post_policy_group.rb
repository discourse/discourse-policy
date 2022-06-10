# frozen_string_literal: true

class PostPolicyGroup < ActiveRecord::Base
  belongs_to :group
  belongs_to :post_policy
end
