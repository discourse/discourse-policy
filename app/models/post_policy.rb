# frozen_string_literal: true

class PostPolicy < ActiveRecord::Base
  belongs_to :post
  belongs_to :group
  has_many :policy_users

  enum renew_interval: { monthly: 0, quarterly: 1, yearly: 2 }

  def accepted_by
    return [] if !policy_group

    User.where(id: accepted_policy_users.select(:user_id))
  end

  def revoked_by
    return [] if !policy_group

    User.where(id: revoked_policy_users.select(:user_id))
  end

  def not_accepted_by
    return [] if !policy_group

    policy_group_users.where.not(id: accepted_policy_users.select(:user_id))
  end

  private

  def accepted_policy_users
    policy_users.accepted.with_version(version)
  end

  def revoked_policy_users
    policy_users.revoked.with_version(version)
  end

  def policy_group_users
    User.joins(:group_users).where('group_users.group_id = ?', policy_group.id)
  end

  def policy_group
    return @policy_group if defined?(@policy_group)

    @policy_group = Group
      .where('id in (SELECT group_id FROM post_policies WHERE post_id = ?)', post.id)
      .first
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
