# frozen_string_literal: true

require "rails_helper"

describe DiscoursePolicy::PolicyGroupAdd do
  before { Jobs.run_immediately! }

  fab!(:user)
  fab!(:group) do
    group = Fabricate(:group)
    group.add(user)
    group
  end

  fab!(:add_user_group) { Fabricate(:group) }

  fab!(:policy) do
    policy = Fabricate(:post_policy, add_users_to_group: add_user_group)
    PostPolicyGroup.create!(post_policy_id: policy.id, group_id: group.id)

    policy
  end

  def accept_policy(policy)
    PolicyUser.add!(user, policy)
  end

  context "when a user has accepted the policy" do
    it "adds user to the group" do
      freeze_time Time.utc(2025)

      accept_policy(policy)
      Jobs.run_immediately!

      expect(policy.accepted_by).to contain_exactly(user)
      expect(Group.find_by(name: group.name).users).to contain_exactly(user)
    end
  end

  context "when a user in the group has not accepted the policy" do
    before do
      group.add(user)
    end

    it "removes user from the group" do
      freeze_time Time.utc(2025)

      policy.reload

      DiscoursePolicy::PolicyGroupAdd.new.execute
      group.reload

      expect(policy.accepted_by).to eq([])
      expect(Group.find_by(name: group.name).users).to eq([])
    end
  end
end