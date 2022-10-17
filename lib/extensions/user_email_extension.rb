# frozen_string_literal: true

module DiscoursePolicy::UserEmailExtension
  def execute(args)
    super(args)

    puts "<--- HERE --->"
    puts args
    puts "<--- /HERE --->"

    # post_title = args[:post_title]
  end
end
