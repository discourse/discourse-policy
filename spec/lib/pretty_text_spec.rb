# frozen_string_literal: true

require 'rails_helper'

describe 'markdown' do
  before do
    SiteSetting.queue_jobs = false
  end

  it "can properly decorate policies" do
    raw = <<~MD
     [policy group=team renew-start="01-01-2010" reminder=weekly accept=banana revoke=apple]
     I always open **doors**!
     [/policy]
    MD

    cooked = (<<~HTML).strip
      <div class="policy" data-group="team" data-version="1" data-reminder="weekly" data-accept="banana" data-revoke="apple" data-renew-start="01-01-2010">
      <p>I always open <strong>doors</strong>!</p>
      </div>
    HTML

    expect(PrettyText.cook(raw)).to match_html(cooked)
  end

  it "triggers a rebaked post message after processing policy" do
    raw = <<~MD
     [policy groups=staff reminder=weekly]
     I pet cats
     [/policy]
    MD
    topic = create_topic

    messages = MessageBus.track_publish("/topic/#{topic.id}") do
      create_post(raw: raw, topic_id: topic.id, user: Fabricate(:admin))
    end

    expect(messages.find { |m| m.data[:type] == :rebaked }).to be_present
  end

  it "sets the custom attribute on posts with policies" do

    SiteSetting.policy_restrict_to_staff_posts = false

    raw = <<~MD
     [policy group=staff reminder=weekly]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw)
    post = Post.find(post.id)

    expect(post.post_policy.group.name).to eq('staff')

    post.revise(post.user, raw: "i am new raw")

    post = Post.find(post.id)

    expect(post.post_policy).to eq(nil)
  end

  it "allows policy to expire for end users on demand" do

    SiteSetting.policy_restrict_to_staff_posts = false

    freeze_time

    user = Fabricate(:admin)

    raw = <<~MD
     [policy group=staff renew=200]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw)
    post.post_policy.group.users << user
    PolicyUser.add!(user, post.post_policy)

    freeze_time(199.days.from_now)
    ::DiscoursePolicy::CheckPolicy.new.execute(nil)
    expect(post.post_policy.accepted_by).to eq([user])

    freeze_time(2.days.from_now)
    ::DiscoursePolicy::CheckPolicy.new.execute(nil)
    expect(post.post_policy.accepted_by).to eq([])

  end

  it "resets list of accepted users if version is bumped" do

    SiteSetting.policy_restrict_to_staff_posts = false

    freeze_time

    user = Fabricate(:admin)

    raw = <<~MD
     [policy group=staff reminder=weekly]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw)
    post.post_policy.group.users << user

    PolicyUser.add!(user, post.post_policy)

    post = Post.find(post.id)

    expect(post.post_policy.accepted_by).to eq([user])

    expect(post.post_policy.reminder).to eq("weekly")
    expect(post.post_policy.last_reminded_at).to eq_time(Time.zone.now)

    raw = <<~MD
     [policy group=staff version=2 reminder=weekly]
     I always open **doors**!
     [/policy]
    MD

    post.revise(post.user, raw: raw)

    post = Post.find(post.id)
    expect(post.post_policy.accepted_by).to eq([])
  end
end
