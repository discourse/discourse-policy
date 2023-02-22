# frozen_string_literal: true

module DiscoursePolicy
  module PostSerializerExtension
    def self.prepended(base)
      base.class_eval do
        attributes :policy_can_accept,
                   :policy_can_revoke,
                   :policy_accepted,
                   :policy_revoked,
                   :policy_not_accepted_by,
                   :policy_not_accepted_by_count,
                   :policy_accepted_by,
                   :policy_accepted_by_count

        delegate :post_policy, to: :object

        alias include_policy_can_accept? include_policy?
        alias include_policy_can_revoke? include_policy?
        alias include_policy_accepted? include_policy?
        alias include_policy_revoked? include_policy?
        alias include_policy_not_accepted_by? include_policy_stats?
        alias include_policy_not_accepted_by_count? include_policy_stats?
        alias include_policy_accepted_by? include_policy_stats?
        alias include_policy_accepted_by_count? include_policy_stats?

        has_many :policy_not_accepted_by, embed: :object, serializer: BasicUserSerializer
        has_many :policy_accepted_by, embed: :object, serializer: BasicUserSerializer
      end
    end

    def include_policy?
      post_custom_fields[DiscoursePolicy::HAS_POLICY]
    end

    def include_policy_stats?
      include_policy? && (scope.is_admin? || !post_policy.private?)
    end

    def policy_can_accept
      scope.authenticated? &&
        (SiteSetting.policy_easy_revoke || post_policy.not_accepted_by.exists?(id: scope.user.id))
    end

    def policy_can_revoke
      scope.authenticated? &&
        (SiteSetting.policy_easy_revoke || post_policy.accepted_by.exists?(id: scope.user.id))
    end

    def policy_accepted
      scope.authenticated? && post_policy.accepted_by.exists?(id: scope.user.id)
    end

    def policy_revoked
      scope.authenticated? && post_policy.revoked_by.exists?(id: scope.user.id)
    end

    def policy_not_accepted_by
      post_policy.not_accepted_by.limit(DiscoursePolicy::POLICY_USER_DEFAULT_LIMIT)
    end

    def policy_not_accepted_by_count
      post_policy.not_accepted_by.size
    end

    def policy_accepted_by
      post_policy.accepted_by.limit(DiscoursePolicy::POLICY_USER_DEFAULT_LIMIT)
    end

    def policy_accepted_by_count
      post_policy.accepted_by.size
    end
  end
end
