# frozen_string_literal: true

module Jobs

  # It would be optimal to queue these rather than send them directly
  class ::DiscoursePolicy::EnqueueAlertEmails < ::Jobs::Scheduled

    every 1.hour
    def execute(args = nil)

    end
  end
end
