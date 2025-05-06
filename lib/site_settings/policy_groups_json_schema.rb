# frozen_string_literal: true

module DiscoursePolicy
  module SiteSettings
    class PolicyGroupsJsonSchema
      def self.schema
        @schema ||= {
          type: "array",
          uniqueItems: true,
          items: {
            type: "object",
            title: "Policy User Groups",
            properties: {
              group_name: {
                type: "string",
                description: "Name of the group that users will be added to",
              },
              policy: {
                type: "string",
                description: "Policy that the user group will be associated with",
              },
            }
          }
        }
      end
    end
  end
end