# frozen_string_literal: true

class PolicyMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def send_notice(user_email, post_url)
    build_email(
      user_email,
      template: 'policy_mailer',
      base_url: Discourse.base_url,
      post_url: post_url
    )
  end
end
