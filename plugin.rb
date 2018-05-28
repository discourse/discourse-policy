# name: discourse-policy
# about: apply policies to Discourse topics
# version: 0.1
# authors: Sam Saffron
# url:

register_asset "stylesheets/common/discourse-policy.scss"

enabled_site_setting :policy_enabled

PLUGIN_NAME ||= "discourse_policy".freeze

after_initialize do

  module ::DiscoursePolicy

    AcceptedBy = "PolicyAcceptedBy"
    PolicyGroup = "PolicyGroup"
    PolicyVersion = "PolicyVersion"
    PolicyReminder = "PolicyReminder"
    LastRemindedAt = "LastRemindedAt"

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscoursePolicy
    end
  end

  require File.expand_path("../jobs/scheduled/check_policy.rb", __FILE__)

  Post.register_custom_field_type DiscoursePolicy::AcceptedBy, [:integer]
  Post.register_custom_field_type DiscoursePolicy::LastRemindedAt, :integer

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

    private

    def change_accepted(type)
      if !SiteSetting.policy_enabled
        raise Discourse::NotFound
      end

      params.require(:post_id)

      post = Post.find(params[:post_id])
      unless group_name = post.custom_fields[DiscoursePolicy::PolicyGroup]
        return json_error(message: I18n.t("discourse_policy.no_policy"))
      end

      unless group = Group.find_by(name: group_name)
        return json_error(message: I18n.t("discourse_policy.group_not_found"))
      end

      unless group.group_users.where(user_id: current_user.id)
        return json_error(message: I18n.t("discourse_policy.user_missing"))
      end

      if group.user_count > SiteSetting.policy_max_group_size
        return json_error(message: I18n.t("discourse_policy.too_large"))
      end

      if type == :add
        PostCustomField.create(
          post_id: post.id,
          name: DiscoursePolicy::AcceptedBy,
          value: current_user.id
        )
      else
        # API needs love here...
        PostCustomField.where(
          post_id: post.id,
          name: DiscoursePolicy::AcceptedBy,
          value: current_user.id
        ).delete_all
      end

      post.publish_change_to_clients!(:policy_change)

      render json: success_json
    end
  end

  DiscoursePolicy::Engine.routes.draw do
    put "/accept" => "policy#accept"
    put "/unaccept" => "policy#unaccept"
  end

  Discourse::Application.routes.append do
    mount ::DiscoursePolicy::Engine, at: "/policy"
  end

  on(:reduce_cooked) do |fragment, post|
    # email mangling goes here
  end

  on(:post_process_cooked) do |doc, post|
    has_group = false

    if policy = doc.search('.policy')&.first
      if group = policy["data-group"]
        if Group.where(name: group).exists
          post.custom_fields[DiscoursePolicy::PolicyGroup] = group
          post.save_custom_fields
          has_group = true
        end
      end

      if version = policy["data-version"]
        old_version = post.custom_fields[DiscoursePolicy::PolicyVersion] || "1"
        if version != old_version
          post.custom_fields[DiscoursePolicy::AcceptedBy] = []
          post.custom_fields[DiscoursePolicy::PolicyVersion] = version
          post.save_custom_fields
        end
      end

      if reminder = policy["data-reminder"]
        post.custom_fields[DiscoursePolicy::PolicyReminder] = reminder
        post.custom_fields[DiscoursePolicy::LastRemindedAt] ||= Time.now.to_i
        post.save_custom_fields
      end
    end

    if !has_group && post.custom_fields[DiscoursePolicy::PolicyGroup]
      post.custom_fields[DiscoursePolicy::PolicyGroup] = nil
      post.save_custom_fields
    end
  end

  # on(:post_created) do |post|
  # end

  TopicView.default_post_custom_fields << DiscoursePolicy::AcceptedBy
  TopicView.default_post_custom_fields << DiscoursePolicy::PolicyGroup

  require_dependency 'post_serializer'
  class ::PostSerializer
    attributes :policy_not_accepted_by, :policy_accepted_by

    def policy_not_accepted_by
      return if !policy_group

      accepted = post_custom_fields[DiscoursePolicy::AcceptedBy]
      policy_group_users.reject do |u|
        accepted&.include?(u.id)
      end.map do |u|
        BasicUserSerializer.new(u, root: false).as_json
      end
    end

    def policy_accepted_by
      return if !policy_group

      accepted = post_custom_fields[DiscoursePolicy::AcceptedBy]
      policy_group_users.reject do |u|
        !accepted&.include?(u.id)
      end.map do |u|
        BasicUserSerializer.new(u, root: false).as_json
      end
    end

    private

    def policy_group_users
      @policy_group_users ||= User.joins(:group_users)
        .where('group_users.group_id = ?', policy_group.id)
        .select(:id, :username, :uploaded_avatar_id).to_a
    end

    def policy_group
      return @policy_group == :nil ? nil : @policy_group if @policy_group
      @policy_group = :nil
      if group_name = post_custom_fields[DiscoursePolicy::PolicyGroup]
        @policy_group = Group.where(name: group_name)
          .where('user_count < ?', SiteSetting.policy_max_group_size)
          .first || :nil
      end
    end
  end

end
