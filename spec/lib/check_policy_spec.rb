# frozen_string_literal: true

require 'rails_helper'

describe DiscoursePolicy::CheckPolicy do

  before do
    Jobs.run_immediately!
  end

  fab!(:user1) do
    Fabricate(:user)
  end

  fab!(:user2) do
    Fabricate(:user)
  end

  fab!(:group) do
    group = Fabricate(:group)
    group.add(user1)
    group.add(user2)
    group
  end

  it "correctly renews policies" do

    freeze_time Time.utc(2019)

    raw = <<~MD
     [policy group=#{group.name} renew=100 renew-start="17-10-2020"]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))

    [user1, user2].each do |u|
      PostCustomField.create!(
        post_id: post.id,
        name: DiscoursePolicy::AcceptedBy,
        value: u.id
      )
    end

    freeze_time Time.utc(2020)
    DiscoursePolicy::CheckPolicy.new.execute

    post.reload
    # did not hit renew start
    expect(post.custom_fields[DiscoursePolicy::AcceptedBy].length).to eq(2)

    freeze_time Time.utc(2020, 10, 18)

    DiscoursePolicy::CheckPolicy.new.execute

    post.reload
    expect(post.custom_fields[DiscoursePolicy::AcceptedBy]).to eq(nil)

    [user1, user2].each do |u|
      PostCustomField.create!(
        post_id: post.id,
        name: DiscoursePolicy::AcceptedBy,
        value: u.id
      )
    end

    freeze_time (Time.utc(2020, 10, 17) + 101.days)

    DiscoursePolicy::CheckPolicy.new.execute

    post.reload
    expect(post.custom_fields[DiscoursePolicy::AcceptedBy]).to eq(nil)
  end

  it "will correctly notify users" do
    SiteSetting.queue_jobs = false
    freeze_time

    raw = <<~MD
     [policy group=#{group.name} reminder=weekly]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))

    DiscoursePolicy::CheckPolicy.new.execute

    expect(user1.notifications.where(notification_type: Notification.types[:topic_reminder]).count).to eq(0)
    expect(user2.notifications.where(notification_type: Notification.types[:topic_reminder]).count).to eq(0)

    freeze_time 2.weeks.from_now

    DiscoursePolicy::CheckPolicy.new.execute
    DiscoursePolicy::CheckPolicy.new.execute

    expect(user1.notifications.where(notification_type: Notification.types[:topic_reminder], topic_id: post.topic_id, post_number: 1).count).to eq(1)
    expect(user2.notifications.where(notification_type: Notification.types[:topic_reminder], topic_id: post.topic_id, post_number: 1).count).to eq(1)
  end
end
