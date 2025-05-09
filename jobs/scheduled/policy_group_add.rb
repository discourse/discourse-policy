# frozen_string_literal: true

module Jobs
  class ::DiscoursePolicy::PolicyGroupAdd < ::Jobs::Scheduled
    every 15.minutes

    def execute(args = nil)
      return unless SiteSetting.policy_add_to_group_enabled

      begin
        if JSON.parse(SiteSetting.policy_add_to_group_groups).size > 0
          policy_groups_settings = JSON.parse(SiteSetting.policy_add_to_group_groups)

          policy_groups_settings.each do |setting|
            binding.pry

            policy_group = Group.find_by(name: setting['group_name'])
            policy = PostPolicy.find(setting['policy'])

            users_to_add = policy.accepted_by - Group.find_by(name: policy_group.users)
            users_to_remove = Group.find_by(name: policy_group.users) - policy.accepted_by


            users_to_add.each do |user|
              Rails.logger.warn("PolicyGroupAdd: Adding user #{user.username} to group #{policy_group}")
              Group.find_by(name: policy_group).add(user)
            end

            users_to_remove.each do |user|
              Rails.logger.warn("PolicyGroupAdd: Removing user #{user.username} from group #{policy_group}")
              Group.find_by(name: policy_group).remove(user)
            end
          end
        end

      rescue StandardError => e
        Rails.logger.error("PolicyGroupAdd job error: #{e.message}")
      end
    end
  end
end
