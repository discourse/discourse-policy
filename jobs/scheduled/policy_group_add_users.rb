# frozen_string_literal: true

module Jobs
  class ::DiscoursePolicy::PolicyGroupAddUsers < ::Jobs::Scheduled
    every 15.minutes

    def execute(args = nil)
      begin
        add_user_to_group_policies = PostPolicy.where.not(add_users_to_group: nil)

        add_user_to_group_policies.each do |policy|
          user_group_to_join = policy.add_users_group

          users_to_add = policy.accepted_by - Group.find_by(name: user_group_to_join).users

          users_to_remove = Group.find_by(name: user_group_to_join).users - policy.accepted_by

          users_to_add.each do |user|
            Rails.logger.warn("PolicyGroupAddUsers: Adding user #{user.username} to group #{policy_group}")
            Group.find_by(name: policy_group).add(user)
          end

          users_to_remove.each do |user|
            Rails.logger.warn("PolicyGroupAddUsers: Removing user #{user.username} from group #{policy_group}")
            Group.find_by(name: policy_group).remove(user)
          end
        end

      rescue StandardError => e
        Rails.logger.error("PolicyGroupAddUsers job error: #{e.message}")
      end
    end
  end
end
