# frozen_string_literal: true

require 'rails_helper'

describe DiscoursePolicy::SendEmails do

  before do
    Jobs.run_immediately!
  end

  # fab!(:user1) do
  #   Fabricate(:user)
  # end
  #
  # fab!(:user2) do
  #   Fabricate(:user)
  # end

  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }

  fab!(:group) do
    group = Fabricate(:group)
    group.add(user1)
    group.add(user2)
    group
  end

  it "correctly sends policy alerts" do
    raw = <<~MD
     [policy group=#{group.name} send-email="true"]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))
    post.post_policy.send_email = true

    expect(post.post_policy.not_emailed_to).to eq [user1, user2]

    DiscoursePolicy::SendEmails.new.execute

    post.reload

    expect(post.post_policy.not_emailed_to).to eq []
  end
end
