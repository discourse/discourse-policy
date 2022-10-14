# frozen_string_literal: true

module Jobs
  class PolicyStatusEmail < ::Jobs::Base
    sidekiq_options queue: 'critical'

    def execute(args)
      # we'll need some of this:
      # @user = user
      # @preferences_path = "#{Discourse.base_url}/my/preferences/emails"
      #
      # # TODO: (via chat plugin) remove after the 2.9 release
      # add_unsubscribe_link = UnsubscribeKey.respond_to?(:get_unsubscribe_strategy_for)
      #
      # if add_unsubscribe_link
      #   unsubscribe_key = UnsubscribeKey.create_key_for(@user, "policy_status")
      #   @unsubscribe_link = "#{Discourse.base_url}/email/unsubscribe/#{unsubscribe_key}"
      #   opts[:unsubscribe_url] = @unsubscribe_link
      # end
      #
      # opts = {
      #   from_alias: I18n.t("user_notifications.policy_status.from", site_name: Email.site_title),
      #   subject: I18n.t("user_notifications.policy_status.subject"),
      #   add_unsubscribe_link: false,
      # }
      message = PolicyMailer.send_notice(args[:user_email], args[:post_url])
      Email::Sender.new(message, 'policy_notice').send
    end

  end
end
