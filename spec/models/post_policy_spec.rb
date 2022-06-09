# frozen_string_literal: true

require 'rails_helper'

describe PostPolicy do
  before do
    Jobs.run_immediately!
  end

  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }
  fab!(:inactive_user) { Fabricate(:user, active: false) }
  fab!(:suspended_user) { Fabricate(:user, suspended_till: 1.year.from_now) }

  fab!(:group) do
    group = Fabricate(:group)
    group.add(user1)
    group.add(user2)
    group.add(inactive_user)
    group.add(suspended_user)
    group
  end

  fab!(:policy) {
    policy = Fabricate(:post_policy)
    PostPolicyGroup.create!(post_policy_id: policy.id, group_id: group.id)
    policy
  }

  describe "#accepted_by" do
    it "returns empty if no policy group" do
      PolicyUser.add!(user1, policy)
      Group.delete_all

      expect(policy.accepted_by).to eq []
    end

    it "shows users who accepted ordered by id" do
      PolicyUser.add!(user2, policy)
      PolicyUser.add!(user1, policy)

      expect(policy.accepted_by).to eq [user1, user2]
    end

    it "excludes inactive or suspended users" do
      PolicyUser.add!(inactive_user, policy)
      PolicyUser.add!(suspended_user, policy)

      expect(policy.accepted_by).to eq []
    end
  end

  describe "#revoked_by" do
    it "returns empty if no policy group" do
      PolicyUser.add!(user1, policy)
      Group.delete_all

      expect(policy.revoked_by).to eq []
    end

    it "shows users who revoked ordered by id" do
      PolicyUser.remove!(user2, policy)
      PolicyUser.remove!(user1, policy)

      expect(policy.revoked_by).to eq [user1, user2]
    end

    it "excludes inactive or suspended users" do
      PolicyUser.remove!(inactive_user, policy)
      PolicyUser.remove!(suspended_user, policy)

      expect(policy.revoked_by).to eq []
    end
  end

  describe "#not_accepted_by" do
    it "returns empty if no policy group" do
      PolicyUser.add!(user1, policy)
      Group.delete_all

      expect(policy.not_accepted_by).to eq []
    end

    it "shows users who have not accepted ordered by id" do
      expect(policy.not_accepted_by).to eq [user1, user2]
    end

    it "excludes inactive or suspended users" do
      expect(policy.not_accepted_by).to_not include(inactive_user, suspended_user)
    end
  end
end
