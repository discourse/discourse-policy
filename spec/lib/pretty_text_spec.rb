require 'rails_helper'

describe 'markdown' do

  it "can properly decorate policies" do
    raw = <<~MD
     [policy group=team reminder=weekly accept=banana revoke=apple]
     I always open **doors**!
     [/policy]
    MD

    cooked = (<<~HTML).strip
      <div class="policy" data-group="team" data-version="1" data-reminder="weekly" data-accept="banana" data-revoke="apple">
      <p>I always open <strong>doors</strong>!</p>
      </div>
    HTML

    expect(PrettyText.cook raw).to eq(cooked)
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

    expect(post.custom_fields[DiscoursePolicy::PolicyGroup]).to eq('staff')

    post.revise(post.user, raw: "i am new raw")

    post = Post.find(post.id)

    expect(post.custom_fields['policy_group']).to eq(nil)
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

    PostCustomField.create!(post_id: post.id, name: DiscoursePolicy::AcceptedBy, value: user.id)

    post = Post.find(post.id)

    expect(post.custom_fields[DiscoursePolicy::AcceptedBy]).to eq([user.id])
    expect(post.custom_fields[DiscoursePolicy::PolicyReminder]).to eq("weekly")
    expect(post.custom_fields[DiscoursePolicy::LastRemindedAt]).to eq(Time.now.to_i)

    raw = <<~MD
     [policy group=staff version=2 reminder=weekly]
     I always open **doors**!
     [/policy]
    MD

    post.revise(post.user, raw: raw)

    post = Post.find(post.id)
    expect(post.custom_fields[DiscoursePolicy::AcceptedBy]).to eq(nil)

  end
end
