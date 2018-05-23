require 'rails_helper'

describe 'markdown' do

  it "can properly decorate policies" do
    raw = <<~MD
     [policy group=team reminder=weekly]
     I always open **doors**!
     [/policy]
    MD

    cooked = (<<~HTML).strip
      <div class="policy" data-group="team" data-reminder="weekly">
      <p>I always open <strong>doors</strong>!</p>
      </div>
    HTML

    expect(PrettyText.cook raw).to eq(cooked)
  end

  it "sets the custom attribute on posts with policies" do
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
end
