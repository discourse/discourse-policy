require 'rails_helper'

describe DiscoursePolicy::CheckPolicy do
  it "will correctly notify users" do

    freeze_time

    group = Fabricate(:group)
    user1 = Fabricate(:user)
    user2 = Fabricate(:user)

    group.add(user1)
    group.add(user2)

    raw = <<~MD
     [policy group=#{group.name} reminder=weekly]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw)

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
