# frozen_string_literal: true

class PolicyUser < ActiveRecord::Base
  belongs_to :post_policy
  belongs_to :user

  scope :accepted, -> { where.not(accepted_at: nil).where(revoked_at: nil, expired_at: nil) }
  scope :with_version, ->(version) { where(version: version) }

  def self.add!(user, post_policy)
    self.create!(
      post_policy_id: post_policy.id,
      user_id: user.id,
      accepted_at: Time.zone.now,
      version: post_policy.version
    )
  end

  def self.remove!(user, post_policy)
    post_policy
      .policy_users
      .accepted
      .with_version(post_policy.version)
      .where(user: user)
      .update_all(revoked_at: Time.zone.now)
  end
end
