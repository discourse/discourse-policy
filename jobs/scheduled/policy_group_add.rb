# frozen_string_literal: true

module Jobs
  class ::DiscoursePolicy::PolicyGroupAdd < ::Jobs::Scheduled
    every 15.minutes

    def execute(args = nil)
      begin
        binding.pry
        # find policies with "add to group" setting
        add_user_to_group_policies = PostPolicy.where.not(add_users_to_group: nil)

        # for each policy, find the group
        # errors with the following:
        add_user_to_group_policies.each do |policy|
          # should probably ensure this can work for more than one group
          user_group_to_join = policy.add_users_to_group

          # find users that have accepted the policy but aren't in the group yet
          users_to_add = policy.accepted_by - Group.find_by(name: user_group_to_join).users
          # find users that are in the group but haven't accepted the policy
          users_to_remove = Group.find_by(name: user_group_to_join).users - policy.accepted_by

          # for each accepting user, add user to group
          users_to_add.each do |user|
            Rails.logger.warn("PolicyGroupAdd: Adding user #{user.username} to group #{policy_group}")
            Group.find_by(name: policy_group).add(user)
          end

          # for each user in the group that hasn't accepted the policy, remove user from group
          users_to_remove.each do |user|
            Rails.logger.warn("PolicyGroupAdd: Removing user #{user.username} from group #{policy_group}")
            Group.find_by(name: policy_group).remove(user)
          end
        end

      rescue StandardError => e
        Rails.logger.error("PolicyGroupAdd job error: #{e.message}")
      end
    end
  end
end
