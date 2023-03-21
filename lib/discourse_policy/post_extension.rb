# frozen_string_literal: true

module DiscoursePolicy
  module PostExtension
    def self.prepended(base)
      base.class_eval { has_one :post_policy, dependent: :destroy }
    end
  end
end
