# frozen_string_literal: true

# name: discourse-policy
# about: Apply policies to Discourse topics
# version: 0.1
# authors: Sam Saffron
# url: https://github.com/discourse/discourse-policy
# transpile_js: true

register_asset "stylesheets/common/discourse-policy.scss"
register_asset "stylesheets/common/discourse-policy-builder.scss"

register_svg_icon "user-check"
register_svg_icon "file-signature"

enabled_site_setting :policy_enabled

after_initialize do
  module ::DiscoursePolicy
    PLUGIN_NAME = "discourse_policy"
    HAS_POLICY = "HasPolicy"
    POLICY_USER_DEFAULT_LIMIT = 25

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscoursePolicy
    end
  end

  require_relative "app/controllers/policy_controller"
  require_relative "app/models/policy_user"
  require_relative "app/models/post_policy"
  require_relative "app/models/post_policy_group"
  require_relative "jobs/scheduled/check_policy"

  DiscoursePolicy::Engine.routes.draw do
    put "/accept" => "policy#accept"
    put "/unaccept" => "policy#unaccept"
    get "/accepted" => "policy#accepted"
    get "/not-accepted" => "policy#not_accepted"
  end

  Discourse::Application.routes.append do
    mount ::DiscoursePolicy::Engine, at: "/policy"
  end

  TopicView.default_post_custom_fields << DiscoursePolicy::HAS_POLICY

  on(:post_process_cooked) do |doc, post|
    has_group = false

    if !SiteSetting.policy_restrict_to_staff_posts || post&.user&.staff?
      if policy = doc.search('.policy')&.first

        post_policy = post.post_policy || post.build_post_policy

        group_names = []

        if group = policy["data-group"]
          group_names << group
        end

        if groups = policy["data-groups"]
          group_names.concat(groups.split(","))
        end

        new_group_ids = Group.where('name in (?)', group_names).pluck(:id)

        if new_group_ids.length > 0
          has_group = true
        end

        existing_ids = post_policy.post_policy_groups.pluck(:group_id)

        missing = (new_group_ids - existing_ids)

        new_relations = []

        post_policy.post_policy_groups.each do |relation|
          if new_group_ids.include?(relation.group_id)
            new_relations << relation
          end
        end

        missing.each do |id|
          new_relations << PostPolicyGroup.new(post_policy_id: post_policy.id, group_id: id)
        end

        post_policy.post_policy_groups = new_relations

        renew_days = policy["data-renew"]
        if (renew_days.to_i) > 0 || PostPolicy.renew_intervals.keys.include?(renew_days)
          post_policy.renew_days = PostPolicy.renew_intervals.keys.include?(renew_days) ? nil : renew_days
          post_policy.renew_interval = post_policy.renew_days.present? ? nil : renew_days

          post_policy.renew_start = nil

          if (renew_start = policy["data-renew-start"])
            begin
              renew_start = Date.parse(renew_start)
              post_policy.renew_start = renew_start
              if !post_policy.next_renew_at ||
                  post_policy.next_renew_at < renew_start
                post_policy.next_renew_at = renew_start
              end
            rescue ArgumentError
              # already nil
            end
          else
            post_policy.next_renew_at = nil
          end

        else
          post_policy.renew_days = nil
          post_policy.renew_start = nil
          post_policy.next_renew_at = nil
        end

        if version = policy["data-version"]
          old_version = post_policy.version || "1"
          post_policy.version = version if version != old_version
        end

        if reminder = policy["data-reminder"]
          post_policy.reminder = reminder
          post_policy.last_reminded_at ||= Time.zone.now
        end

        post_policy.private = policy["data-private"] == "true"

        if has_group
          if !post.custom_fields[DiscoursePolicy::HAS_POLICY]
            post.custom_fields[DiscoursePolicy::HAS_POLICY] = true
            post.save_custom_fields
          end
          post_policy.save!
        end
      end
    end

    if !has_group && (post.custom_fields[DiscoursePolicy::HAS_POLICY] || !post_policy&.new_record?)
      post.custom_fields.delete(DiscoursePolicy::HAS_POLICY)
      post.save_custom_fields
      PostPolicy.where(post_id: post.id).destroy_all
    end
  end

  require_dependency 'post'
  class ::Post
    has_one :post_policy, dependent: :destroy
  end

  require_dependency 'post_serializer'
  class ::PostSerializer
    attributes :policy_can_accept,
               :policy_can_revoke,
               :policy_accepted,
               :policy_revoked,
               :policy_not_accepted_by,
               :policy_not_accepted_by_count,
               :policy_accepted_by,
               :policy_accepted_by_count

    delegate :post_policy, to: :object

    def include_policy?
      post_custom_fields[DiscoursePolicy::HAS_POLICY]
    end

    def include_policy_stats?
      include_policy? && (scope.is_admin? || !post_policy.private?)
    end

    alias :include_policy_can_accept? :include_policy?
    alias :include_policy_can_revoke? :include_policy?
    alias :include_policy_accepted? :include_policy?
    alias :include_policy_revoked? :include_policy?
    alias :include_policy_not_accepted_by? :include_policy_stats?
    alias :include_policy_not_accepted_by_count? :include_policy_stats?
    alias :include_policy_accepted_by? :include_policy_stats?
    alias :include_policy_accepted_by_count? :include_policy_stats?

    has_many :policy_not_accepted_by, embed: :object, serializer: BasicUserSerializer
    has_many :policy_accepted_by, embed: :object, serializer: BasicUserSerializer

    def policy_can_accept
      scope.authenticated? && (SiteSetting.policy_easy_revoke || post_policy.not_accepted_by.exists?(id: scope.user.id))
    end

    def policy_can_revoke
      scope.authenticated? && (SiteSetting.policy_easy_revoke || post_policy.accepted_by.exists?(id: scope.user.id))
    end

    def policy_accepted
      scope.authenticated? && post_policy.accepted_by.exists?(id: scope.user.id)
    end

    def policy_revoked
      scope.authenticated? && post_policy.revoked_by.exists?(id: scope.user.id)
    end

    def policy_not_accepted_by
      post_policy.not_accepted_by.limit(DiscoursePolicy::POLICY_USER_DEFAULT_LIMIT)
    end

    def policy_not_accepted_by_count
      post_policy.not_accepted_by.size
    end

    def policy_accepted_by
      post_policy.accepted_by.limit(DiscoursePolicy::POLICY_USER_DEFAULT_LIMIT)
    end

    def policy_accepted_by_count
      post_policy.accepted_by.size
    end
  end

  add_report("unaccepted-policies") do |report|
    report.modes = [:table]

    report.labels = [
      {
        property: :topic_id,
        title: I18n.t("discourse_policy.reports.unaccepted_policies.labels.topic_id"),
      },
      {
        property: :user_id,
        title: I18n.t("discourse_policy.reports.unaccepted_policies.labels.user_id"),
      },
    ]

    results = DB.query(<<~SQL)
      SELECT distinct t.id AS topic_id, gu.user_id AS user_id
      FROM post_policies pp
      JOIN post_policy_groups pg on pg.post_policy_id = pp.id
      JOIN posts p ON p.id = pp.post_id AND p.deleted_at is null
      JOIN topics t ON t.id = p.topic_id AND t.deleted_at is null
      JOIN group_users gu ON gu.group_id = pg.group_id
      LEFT JOIN policy_users pu ON
        pu.user_id = gu.user_id AND
        pu.post_policy_id = pp.id AND
        pu.accepted_at IS NOT NULL AND
        pu.revoked_at IS NULL AND
        (pu.expired_at IS NULL OR pu.expired_at < pu.accepted_at) AND
        ((pu.version IS NULL AND pp.version IS NULL) OR
        (pp.version IS NOT NULL AND pu.version IS NOT NULL AND pu.version = pp.version))
      WHERE pu.id IS NULL
    SQL

    report.data = []
    results.each do |row|
      data = {}
      data[:user_id] = row.user_id
      data[:topic_id] = row.topic_id
      report.data << data
    end
  end
end
