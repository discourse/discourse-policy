# frozen_string_literal: true

module Jobs
  class ::DiscoursePolicy::PolicyGroupAdd < ::Jobs::Scheduled
    every 15.minutes

    def execute(_args)
      return unless SiteSetting.policy_add_to_group_enabled

      SiteSetting.policy_add_to_group_groups.each do |group|
        begin
          group_to_add_users = Group.find_by(name: group['group_name'])
          users_to_add = PostPolicy.find_by(name: group['policy']).accepted_by - Group.find_by(name: group_to_add_users.users)

          users_to_add.each do |user|
            Rails.logger.warn("PolicyGroupAdd: Adding user #{user.username} to group #{group_to_add_users}")
            Group.find_by(name: group_to_add_users).add(user)
          end
        end

        # the other example also has users removed from the group when they haven't accepted the policy -- not sure if this is something we want to do as well in terms of user experience
      rescue StandardError => e
        Rails.logger.error("PolicyGroupAdd job error: #{e.message}")
      end
    end
  end
end
