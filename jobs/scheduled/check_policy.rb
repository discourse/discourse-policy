module Jobs

  class ::DiscoursePolicy::CheckPolicy < Jobs::Scheduled

    every 6.hours

    def execute(args = nil)
      sql = <<~SQL
        SELECT p.id FROM post_custom_fields f
        JOIN post_custom_fields f2 ON f2.post_id = f.post_id
          AND f2.name = '#{::DiscoursePolicy::LastRemindedAt}'
        JOIN posts p ON p.id = f.post_id
        JOIN topics t ON t.id = p.topic_id
        WHERE t.deleted_at IS NULL
          AND p.deleted_at IS NULL
          AND t.archetype = 'regular'
          AND f.name = '#{::DiscoursePolicy::PolicyReminder}'
          AND (
          (
            f.value = 'weekly' AND
            f2.value::integer < :weekly
          ) OR
          (
            f.value = 'daily' AND
            f2.value::integer < :daily
          ))
      SQL

      post_ids = DB.query_single(
        sql,
        weekly: 1.week.ago.to_i,
        daily: 1.day.ago.to_i
      )

      if post_ids.length > 0
        Post.where(id: post_ids).each do |post|

          post.custom_fields[DiscoursePolicy::LastRemindedAt] = Time.now.to_i
          post.save_custom_fields

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

    end

    def missing_users(post)
      if !group_name = post.custom_fields[DiscoursePolicy::PolicyGroup]
        return []
      end

      group = Group.find_by(name: group_name)

      if !group
        return []
      end

      User.joins(:group_users)
        .where('group_users.group_id = ?', group.id)
        .where('users.id NOT IN (?)', post.custom_fields[DiscoursePolicy::AcceptedBy] || [-1])
    end

  end
end
