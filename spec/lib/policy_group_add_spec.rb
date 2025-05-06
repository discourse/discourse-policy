# frozen_string_literal: true

require "rails_helper"

describe DiscoursePolicy::PolicyGroupAdd do
  before { Jobs.run_immediately! }

  fab!(:user)
  fab!(:group)

  def accept_policy(post)
    PolicyUser.add!(user, post.post_policy)
  end

  it "adds user to group if they have accepted the policy" do
    freeze_time Time.utc(2025)

    raw = <<~MD
      [policy group=#{group.name} renew=400]
      I always open **doors**!
      [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))
    accept_policy(post)

    DiscoursePolicy::PolicyGroupAdd.new.execute

    expect(post.post_policy.accepted_by).to contain_exactly(user)
    expect(Group.find_by(name: group.name).users).to include(user)
  end

  it "does not add user to group if they have not accepted the policy" do
    freeze_time Time.utc(2025)

    raw = <<~MD
      [policy group=#{group.name} renew=400]
      I always open **doors**!
      [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))

    DiscoursePolicy::PolicyGroupAdd.new.execute

    expect(post.post_policy.accepted_by).not_to include(user)
    expect(Group.find_by(name: group.name).users).not_to include(user)
  end

  # it "" do
  #   removes users from selected groups if they have not accepted the policy upon enabling this feature?
  # end
end