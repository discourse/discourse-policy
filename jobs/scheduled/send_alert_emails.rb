# frozen_string_literal: true

module Jobs

  class ::DiscoursePolicy::SendAlertEmails < ::Jobs::Scheduled

    every 1.hour
    def execute(args = nil)

    end
  end
end
