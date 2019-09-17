# frozen_string_literal: true

class PostPolicy < ActiveRecord::Base
  belongs_to :post
  belongs_to :group
end
