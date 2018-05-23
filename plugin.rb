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

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscoursePolicy
    end
  end

  Post.register_custom_field_type DiscoursePolicy::AcceptedBy, [:integer]

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
      params.require(:post_id)

      post = Post.find(params[:post_id])
      unless group_name = post.custom_fields[DiscoursePolicy::PolicyGroup]
        return json_error(message: "no policy exists on post")
      end

      unless group = Group.find_by(name: group_name)
        return json_error(message: "group not found for policy")
      end

      unless group.group_users.where(user_id: current_user.id)
        return json_error(message: "user does not exist in group")
      end

      if type == :add
        post.custom_fields[DiscoursePolicy::AcceptedBy] ||= []
        post.custom_fields[DiscoursePolicy::AcceptedBy] << current_user.id
        post.save_custom_fields
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
    if policy = doc.search('.policy')&.first
      if group = policy["data-group"]
        if Group.where(name: group).exists
          post.custom_fields[DiscoursePolicy::PolicyGroup] = group
          post.save_custom_fields
          return
        end
      end
    end

    if post.custom_fields[DiscoursePolicy::PolicyGroup]
      post.custom_fields[DiscoursePolicy::PolicyGroup] = nil
      post.save_custom_fields
    end
  end

  on(:post_created) do |post|
    # MessageBus.publish("/polls/#{post.topic_id}", post_id: post.id, polls: post.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD])
  end

  on(:merging_users) do |source_user, target_user|
    # TODO
  end

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
        @policy_group = Group.find_by(name: group_name) || :nil
      end
    end
  end

end
