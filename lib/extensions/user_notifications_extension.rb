# frozen_string_literal: true

module DiscoursePolicy::UserNotificationsExtension
  def policy_email(user, opts)
    @user = user
    puts "<--- notification --->"
    puts opts
    build_summary_for(user)
    @preferences_path = "#{Discourse.base_url}/my/preferences/email"
    # puts opts[:user_id]

    # TODO(mark, a la chat plugin): Remove after the 2.9 release
    add_unsubscribe_link = UnsubscribeKey.respond_to?(:get_unsubscribe_strategy_for)

    if add_unsubscribe_link
      unsubscribe_key = UnsubscribeKey.create_key_for(@user, "policy_email")
      @unsubscribe_link = "#{Discourse.base_url}/email/unsubscribe/#{unsubscribe_key}"
      # opts[:unsubscribe_url] = @unsubscribe_link
    end

    # puts opts[:post_title]
    #
    # opts = {
    #   subject: opts[:post_title]
    # }
    # puts opts
    # opts = {
    #   subject: 'test subject!',
    # }
    #
    # puts opts
    # puts "<--- /notification --->"

    build_email(user.email, opts)
  end
end
