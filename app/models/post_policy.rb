# frozen_string_literal: true

class PostPolicy < ActiveRecord::Base

  self.ignored_columns = [
    "group_id" # TODO (sam) (2023-01-01) remove
  ]

  belongs_to :post
  has_many :post_policy_groups, dependent: :destroy
  has_many :groups, through: :post_policy_groups
  has_many :policy_users

  enum renew_interval: { monthly: 0, quarterly: 1, yearly: 2 }

  def accepted_by
    return [] if !policy_groups

    User.activated.not_suspended.where(id: accepted_policy_users.select(:user_id)).order(:id)
  end

  def revoked_by
    return [] if !policy_groups

    User.activated.not_suspended.where(id: revoked_policy_users.select(:user_id)).order(:id)
  end

  def not_accepted_by
    return [] if !policy_groups

    policy_group_users.where.not(id: accepted_policy_users.select(:user_id))
  end

  private

  def accepted_policy_users
    policy_users.accepted.with_version(version)
  end

  def revoked_policy_users
    policy_users.revoked.with_version(version)
  end

  def policy_groups
    return @policy_groups if defined?(@policy_groups)

    @policy_groups = groups.to_a
    if @policy_groups.blank?
      @policy_groups = nil
    end

    @policy_groups
  end

  private

  def policy_group_users
    User.activated.not_suspended.joins(:group_users).where('group_users.group_id in (?)', policy_groups.map(&:id)).order(:id)
  end
end

# == Schema Information
#
# Table name: post_policies
#
#  id               :bigint           not null, primary key
#  post_id          :bigint           not null
#  renew_start      :datetime
#  renew_days       :integer
#  next_renew_at    :datetime
#  reminder         :string
#  last_reminded_at :datetime
#  version          :string
#  group_id         :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  renew_interval   :integer
#  private          :boolean          default(FALSE), not null
#
