# frozen_string_literal: true

# name: discourse-policy
# about: apply policies to Discourse topics
# version: 0.1
# authors: Sam Saffron
# url: https://github.com/discourse/discourse-policy

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

        if group = policy["data-group"]
          if group = Group.find_by(name: group)
            post_policy.group_id = group.id
            has_group = true
          end
        end

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
end
