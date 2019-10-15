# frozen_string_literal: true

module Jobs

  class ::DiscoursePolicy::CheckPolicy < ::Jobs::Scheduled

    every 6.hours

    def execute(args = nil)
      sql = <<~SQL
        SELECT p.id FROM post_policies pp
        JOIN posts p ON p.id = pp.post_id
        JOIN topics t ON t.id = p.topic_id
        WHERE t.deleted_at IS NULL
          AND p.deleted_at IS NULL
          AND t.archetype = 'regular'
          AND (
          (
            reminder = 'weekly' AND
            last_reminded_at < :weekly
          ) OR
          (
            reminder = 'daily' AND
            last_reminded_at < :daily
          ))
      SQL

      post_ids = DB.query_single(
        sql,
        weekly: 1.week.ago,
        daily: 1.day.ago
      )

      if post_ids.length > 0
        Post.where(id: post_ids).find_each do |post|

          post.post_policy.update(last_reminded_at: Time.zone.now)

          missing_users(post).each do |user|
            user.notifications.create!(
              notification_type: Notification.types[:topic_reminder],
              topic_id: post.topic_id,
              post_number: post.post_number,
              data: { topic_title: post.topic.title, display_username: user.username }.to_json
            )
          end
        end
      end

      PostPolicy.where('next_renew_at < ?', Time.zone.now).find_each do |policy|
        policy.user_policy_logs.accepted.update_all(expired_at: Time.zone.now)
        next_renew = policy.renew_start
        if policy.renew_days < 1
          Rails.logger.warn("Invalid policy on post #{policy.post_id}")
        else
          while next_renew < Time.zone.now
            next_renew += policy.renew_days.days
          end
        end
        policy.update(next_renew_at: next_renew)
      end

      sql = <<~SQL
      UPDATE user_policy_logs
      SET expired_at = :now
      FROM user_policy_logs pl
      INNER JOIN post_policies pp ON pp.id = pl.post_policy_id
      WHERE pp.renew_start IS NULL AND
      pp.renew_days IS NOT NULL AND
      pl.accepted_at IS NOT NULL AND
      pl.expired_at IS NULL AND
      pl.revoked_at IS NULL AND
      pl.accepted_at < :now::timestamp - ( INTERVAL '1 day' *  pp.renew_days )
      SQL

      DB.exec(
        sql,
        now: Time.zone.now
      )
    end

    def missing_users(post)
      post.post_policy.not_accepted_by
    end
  end
end
