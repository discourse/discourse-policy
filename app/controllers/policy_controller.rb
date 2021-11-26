# frozen_string_literal: true

class DiscoursePolicy::PolicyController < ::ApplicationController
  requires_plugin DiscoursePolicy::PLUGIN_NAME

  before_action :ensure_logged_in, :set_post

  def accept
    PolicyUser.add!(current_user, @post.post_policy)
    @post.publish_change_to_clients!(:policy_change)

    render json: success_json
  end

  def unaccept
    PolicyUser.remove!(current_user, @post.post_policy)
    @post.publish_change_to_clients!(:policy_change)

    render json: success_json
  end

  def accepted
    users = @post
      .post_policy
      .accepted_by
      .offset(params[:offset])
      .limit(DiscoursePolicy::POLICY_USER_DEFAULT_LIMIT)

    render json: {
      users: serialize_data(users, BasicUserSerializer)
    }
  end

  def not_accepted
    @post = Post.find(params[:post_id])
    users = @post
      .post_policy
      .not_accepted_by
      .offset(params[:offset])
      .limit(DiscoursePolicy::POLICY_USER_DEFAULT_LIMIT)

    render json: {
      users: serialize_data(users, BasicUserSerializer)
    }
  end

  private

  def set_post
    if !SiteSetting.policy_enabled
      raise Discourse::NotFound
    end

    params.require(:post_id)
    @post = Post.find_by(id: params[:post_id])

    if !@post
      raise Discourse::NotFound
    end

    if !@post.post_policy
      return render_json_error(I18n.t("discourse_policy.errors.no_policy"))
    end

    unless group = @post.post_policy.group
      return render_json_error(I18n.t("discourse_policy.error.group_not_found"))
    end

    unless group.group_users.where(user_id: current_user.id)
      return render_json_error(I18n.t("discourse_policy.errors.user_missing"))
    end

    if group.user_count > SiteSetting.policy_max_group_size
      return render_json_error(I18n.t("discourse_policy.errors.too_large"))
    end

    if SiteSetting.policy_restrict_to_staff_posts && !@post.user&.staff?
      return render_json_error(I18n.t("discourse_policy.errors.staff_only"))
    end

    true
  end
end
