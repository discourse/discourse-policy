# frozen_string_literal: true

require 'rails_helper'

describe DiscoursePolicy do
  describe 'post_process_cooked event' do
    before { Jobs.run_immediately! }

    it 'sets next_renew_at when removing renew-start but not renew' do
      group = Fabricate(:group)
      renew_days = 10
      renew_start = 1.day.from_now.to_date
      raw = <<~MD
       [policy group=#{group.name} renew="#{renew_days}" renew-start="#{renew_start.strftime('%F')}"]
        Here's the new policy
       [/policy]
      MD

      post = create_post(raw: raw, user: Fabricate(:admin))
      policy = PostPolicy.find_by(post: post)

      expect(policy.renew_days).to eq(renew_days)
      expect(policy.renew_start).to eq(renew_start)
      expect(policy.next_renew_at.to_date).to eq(renew_start)

      updated_policy = <<~MD
       [policy group=#{group.name} renew="#{renew_days}"]
        Here's the new policy
       [/policy]
      MD

      post.update!(raw: updated_policy)
      post.rebake!
      policy = policy.reload

      expect(policy.renew_days).to eq(renew_days)
      expect(policy.renew_start).to be_nil
      expect(policy.next_renew_at).to be_nil
    end
  end
end
