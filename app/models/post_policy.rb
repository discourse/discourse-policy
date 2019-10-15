# frozen_string_literal: true

class PostPolicy < ActiveRecord::Base
  belongs_to :post
  belongs_to :group
  has_many :user_policy_logs

  def accepted_by
    return [] if !policy_group
    user_policy_logs
      .accepted
      .with_version(version)
      .where(user_id: policy_group_users.map(&:id))
      .includes(:user)
      .map(&:user)
  end

  def not_accepted_by
    return [] if !policy_group
    policy_group_users - accepted_by
  end

  private

  def policy_group_users
    @policy_group_users ||= User.joins(:group_users)
      .where('group_users.group_id = ?', policy_group.id)
      .select(:id, :username, :uploaded_avatar_id).to_a
  end

  def policy_group
    return @policy_group == :nil ? nil : @policy_group if @policy_group
    @policy_group = :nil

    @policy_group = Group
      .where('user_count < ?', SiteSetting.policy_max_group_size)
      .where('id in (SELECT group_id FROM post_policies WHERE post_id = ?)', post.id)
      .first || :nil
  end
end
