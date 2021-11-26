# frozen_string_literal: true

# name: discourse-policy
# about: apply policies to Discourse topics
# version: 0.1
# authors: Sam Saffron
# url: https://github.com/discourse/discourse-policy

register_asset "stylesheets/common/discourse-policy.scss"
register_asset "stylesheets/common/discourse-policy-builder.scss"

register_svg_icon "user-check" if respond_to?(:register_svg_icon)
register_svg_icon "file-signature" if respond_to?(:register_svg_icon)

enabled_site_setting :policy_enabled

PLUGIN_NAME ||= "discourse_policy".freeze

after_initialize do
  module ::DiscoursePolicy
    MAX_POLICY_USER_LIMIT = 25

    HasPolicy = "HasPolicy"

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscoursePolicy
    end
  end

  [
    "../jobs/scheduled/check_policy.rb",
    "../app/models/post_policy",
    "../app/models/policy_user",
  ].each { |path| require File.expand_path(path, __FILE__) }

  require 'post'
  class ::Post
    has_one :post_policy, dependent: :destroy
  end

  require_dependency "application_controller"
  class DiscoursePolicy::PolicyController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_logged_in

    def accept
      change_accepted(:add)
    end

    def unaccept
      change_accepted(:remove)
    end

    def accepted
      post = Post.find(params[:post_id])
      users = post
        .post_policy
        .accepted_by
        .offset(params[:offset])
        .limit(DiscoursePolicy::MAX_POLICY_USER_LIMIT)

      render json: {
        users: serialize_data(users, BasicUserSerializer)
      }
    end

    def not_accepted
      post = Post.find(params[:post_id])
      users = post
        .post_policy
        .not_accepted_by
        .offset(params[:offset])
        .limit(DiscoursePolicy::MAX_POLICY_USER_LIMIT)

      render json: {
        users: serialize_data(users, BasicUserSerializer)
      }
    end

    private

    def change_accepted(type)
      if !SiteSetting.policy_enabled
        raise Discourse::NotFound
      end

      params.require(:post_id)

      post = Post.find(params[:post_id])

      if !post.post_policy
        return render_json_error(I18n.t("discourse_policy.errors.no_policy"))
      end

      unless group = post.post_policy.group
        return render_json_error(I18n.t("discourse_policy.error.group_not_found"))
      end

      unless group.group_users.where(user_id: current_user.id)
        return render_json_error(I18n.t("discourse_policy.errors.user_missing"))
      end

      if group.user_count > SiteSetting.policy_max_group_size
        return render_json_error(I18n.t("discourse_policy.errors.too_large"))
      end

      if SiteSetting.policy_restrict_to_staff_posts && !post.user&.staff?
        return render_json_error(I18n.t("discourse_policy.errors.staff_only"))
      end

      if type == :add
        PolicyUser.add!(current_user, post.post_policy)
      else
        PolicyUser.remove!(current_user, post.post_policy)
      end

      post.publish_change_to_clients!(:policy_change)

      render json: success_json
    end
  end

  DiscoursePolicy::Engine.routes.draw do
    put "/accept" => "policy#accept"
    put "/unaccept" => "policy#unaccept"
    get "/accepted" => "policy#accepted"
    get "/not-accepted" => "policy#not_accepted"
  end

  Discourse::Application.routes.append do
    mount ::DiscoursePolicy::Engine, at: "/policy"
  end

  on(:reduce_cooked) do |fragment, post|
    # email mangling goes here
  end

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

        if has_group
          if !post.custom_fields[DiscoursePolicy::HasPolicy]
            post.custom_fields[DiscoursePolicy::HasPolicy] = true
            post.save_custom_fields
          end
          post_policy.save!
        end
      end
    end

    if !has_group && (post.custom_fields[DiscoursePolicy::HasPolicy] || !post_policy&.new_record?)
      post.custom_fields.delete(DiscoursePolicy::HasPolicy)
      post.save_custom_fields
      PostPolicy.where(post_id: post.id).destroy_all
    end
  end

  # on(:post_created) do |post|
  # end

  TopicView.default_post_custom_fields << DiscoursePolicy::HasPolicy

  require_dependency 'post_serializer'
  class ::PostSerializer
    attributes :policy_can_accept,
               :policy_can_revoke,
               :policy_not_accepted_by,
               :policy_not_accepted_by_count,
               :policy_accepted_by,
               :policy_accepted_by_count

    delegate :post_policy, to: :object

    def include_policy?
      post_custom_fields[DiscoursePolicy::HasPolicy]
    end

    alias :include_policy_can_accept? :include_policy?
    alias :include_policy_can_revoke? :include_policy?
    alias :include_policy_not_accepted_by? :include_policy?
    alias :include_policy_not_accepted_by_count? :include_policy?
    alias :include_policy_accepted_by? :include_policy?
    alias :include_policy_accepted_by_count? :include_policy?

    has_many :policy_not_accepted_by, embed: :object, serializer: BasicUserSerializer
    has_many :policy_accepted_by, embed: :object, serializer: BasicUserSerializer

    def policy_can_accept
      post_policy.not_accepted_by.exists?(id: scope.user&.id)
    end

    def policy_can_revoke
      post_policy.accepted_by.exists?(id: scope.user&.id)
    end

    def policy_not_accepted_by
      post_policy.not_accepted_by.limit(DiscoursePolicy::MAX_POLICY_USER_LIMIT)
    end

    def policy_not_accepted_by_count
      post_policy.not_accepted_by.size
    end

    def policy_accepted_by
      post_policy.accepted_by.limit(DiscoursePolicy::MAX_POLICY_USER_LIMIT)
    end

    def policy_accepted_by_count
      post_policy.accepted_by.size
    end
  end
end
