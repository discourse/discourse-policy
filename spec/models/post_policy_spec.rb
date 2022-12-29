# frozen_string_literal: true

require "rails_helper"

describe PostPolicy do
  before { Jobs.run_immediately! }

  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }
  fab!(:inactive_user) { Fabricate(:user, active: false) }
  fab!(:suspended_user) { Fabricate(:user, suspended_till: 1.year.from_now) }

  fab!(:group1) do
    group = Fabricate(:group)
    group.add(user1)
    group.add(user2)
    group.add(inactive_user)
    group.add(suspended_user)
    group
  end

  fab!(:group2) do
    group = Fabricate(:group)
    group.add(user1)
    group
  end

  fab!(:policy) do
    policy = Fabricate(:post_policy)
    PostPolicyGroup.create!(post_policy_id: policy.id, group_id: group1.id)
    PostPolicyGroup.create!(post_policy_id: policy.id, group_id: group2.id)
    policy
  end

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

    it "has no duplicates for users in multiple groups" do
      PolicyUser.add!(user1, policy)

      expect(policy.accepted_by).to eq [user1]
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

    it "has no duplicates for users in multiple groups" do
      PolicyUser.remove!(user1, policy)

      expect(policy.revoked_by).to eq [user1]
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

  describe "#emailed_by" do
    it "returns empty if no users have requested emails" do
      user1.user_option.update(policy_email_frequency: UserOption.policy_email_frequencies[:never])
      user2.user_option.update(policy_email_frequency: UserOption.policy_email_frequencies[:never])

      expect(policy.emailed_by).to eq []
    end

    it "shows users who have requested emails and have not accepted yet" do
      user1.user_option.update(policy_email_frequency: UserOption.policy_email_frequencies[:always])
      user2.user_option.update(
        policy_email_frequency: UserOption.policy_email_frequencies[:when_away],
      )

      user2.update(last_seen_at: 30.minutes.ago)

      expect(policy.emailed_by).to eq [user1, user2]
    end
  end

  describe "#emailed_by_always" do
    it "shows users who have opted for emails always" do
      user1.user_option.update(policy_email_frequency: UserOption.policy_email_frequencies[:always])
      user2.user_option.update(policy_email_frequency: UserOption.policy_email_frequencies[:never])

      expect(policy.emailed_by_always).to eq [user1]
    end

    it "returns empty if users who requested emails always have accepted" do
      user1.user_option.update(policy_email_frequency: UserOption.policy_email_frequencies[:always])
      user2.user_option.update(policy_email_frequency: UserOption.policy_email_frequencies[:never])

      PolicyUser.add!(user1, policy)

      expect(policy.emailed_by_always).to eq []
    end
  end

  describe "#emailed_by_when_away" do
    it "shows users who have opted for emails when away" do
      user1.user_option.update(
        policy_email_frequency: UserOption.policy_email_frequencies[:when_away],
      )
      user2.user_option.update(policy_email_frequency: UserOption.policy_email_frequencies[:never])

      user1.update(last_seen_at: 30.minutes.ago)

      expect(policy.emailed_by_when_away).to eq [user1]
    end

    it "returns empty if users who requested emails when away have accepted" do
      user1.user_option.update(
        policy_email_frequency: UserOption.policy_email_frequencies[:when_away],
      )
      user2.user_option.update(policy_email_frequency: UserOption.policy_email_frequencies[:never])

      PolicyUser.add!(user1, policy)

      user1.update(last_seen_at: 30.minutes.ago)

      expect(policy.emailed_by_when_away).to eq []
    end
  end
end
