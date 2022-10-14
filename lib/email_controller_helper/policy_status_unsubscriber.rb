# frozen_string_literal: true

module EmailControllerHelper
  class PolicyStatusUnsubscriber < BaseEmailUnsubscriber
    def prepare_unsubscribe_options(controller)
      super(controller)

      # For reference:
      # chat_email_frequencies =
      #   UserOption.chat_email_frequencies.map do |(freq, _)|
      #     [I18n.t("unsubscribe.chat_summary.#{freq}"), freq]
      #   end
      #
      # controller.instance_variable_set(:@chat_email_frequencies, chat_email_frequencies)
      # controller.instance_variable_set(
      #   :@current_chat_email_frequency,
      #   key_owner.user_option.chat_email_frequency,
      # )
    end

    def unsubscribe(params)
      updated = super(params)

      if params[:policy_email_frequency]
        key_owner.user_option.update!(policy_email_frequency: params[:policy_email_frequency])
        updated = true
      end

      updated
    end
  end
end
