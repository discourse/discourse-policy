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

  def not_accepted_by
    return [] if !policy_group

    policy_group_users.where.not(id: accepted_policy_users.select(:user_id))
  end

  private

  def accepted_policy_users
    policy_users.accepted.with_version(version)
  end

  def policy_group_users
    User.joins(:group_users).where('group_users.group_id = ?', policy_group.id)
  end

  def policy_group
    return @policy_group if defined?(@policy_group)

    @policy_group = Group
      .where('user_count < ?', SiteSetting.policy_max_group_size)
      .where('id in (SELECT group_id FROM post_policies WHERE post_id = ?)', post.id)
      .first
  end
end
