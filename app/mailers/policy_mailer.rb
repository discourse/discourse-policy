# frozen_string_literal: true

class PolicyMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def send_notice(user)
    # TODO (mark) get message template working
    # The template *is* being found to set the subject, in the plugin translations,
    # but message body contains "translation missing: en.policy_mailer.text_body_template"
    build_email(user.email,
                template: 'policy_mailer'
    )
  end
end
