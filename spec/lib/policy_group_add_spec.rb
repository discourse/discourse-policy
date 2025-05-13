# frozen_string_literal: true

require "rails_helper"

describe DiscoursePolicy::PolicyGroupAdd do
  before { Jobs.run_immediately! }

  fab!(:user)
  fab!(:group)

  def accept_policy(post)
    PolicyUser.add!(user, post.post_policy)
  end

  context "when a user has accepted the policy" do
    before do
      # mock the user group name on policy
    end


    it "adds user to the group" do
      freeze_time Time.utc(2025)

      raw = <<~MD
        [policy group=#{group.name} renew=400]
        I always open **doors**!
        [/policy]
      MD

      post = create_post(raw: raw, user: Fabricate(:admin))
      accept_policy(post)
      post.reload

      DiscoursePolicy::PolicyGroupAdd.new.execute
      group.reload

      expect(post.post_policy.accepted_by).to contain_exactly(user)
      expect(Group.find_by(name: group.name).users).to contain_exactly(user)
    end
  end

  context "when a user in the group has not accepted the policy" do
    before do
      # mock the user group name on policy
      group.add(user)
    end

    it "removes user from the group" do
      freeze_time Time.utc(2025)

      raw = <<~MD
        [policy group=#{group.name} renew=400]
        I always open **doors**!
        [/policy]
      MD

      post = create_post(raw: raw, user: Fabricate(:admin))
      post.reload

      DiscoursePolicy::PolicyGroupAdd.new.execute
      # group.reload

      expect(post.post_policy.accepted_by).to eq([])
      expect(Group.find_by(name: group.name).users).to eq([])
    end
  end
end