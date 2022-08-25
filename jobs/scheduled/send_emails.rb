# frozen_string_literal: true

module Jobs

  class ::DiscoursePolicy::SendEmails < ::Jobs::Scheduled

    every 1.hour
    def execute(args = nil)
      sql = <<~SQL
        SELECT p.id
          FROM post_policies pp
          JOIN posts p ON p.id = pp.post_id
          JOIN topics t ON t.id = p.topic_id
         WHERE t.deleted_at IS NULL
           AND p.deleted_at IS NULL
           AND t.archetype = 'regular'
           AND pp.send_email = TRUE
      SQL

      post_ids = DB.query_single(sql)

      if post_ids.size > 0
        Post.where(id: post_ids).find_each do |post|
          needs_email(post).each do |user|
            # send the email
            # TODO (mark) this should be queued instead of sending synchronously
            message = PolicyMailer.send_notice(user)
            Email::Sender.new(message, 'policy_notice').send
            # update the policy user
            PolicyUser.set_emailed!(user, post.post_policy)
          end
        end
      end
    end

    def needs_email(post)
      post.post_policy.not_emailed_to
    end
  end
end
