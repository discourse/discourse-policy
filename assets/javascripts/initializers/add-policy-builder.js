import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";

function initializePolicyBuilder(api, container) {
  const currentUser = api.getCurrentUser();
  const siteSettings = container.lookup("site-settings:main");

  api.addToolbarPopupMenuOptionsCallback(() => {
    if (!currentUser) {
      return;
    }

    if (!siteSettings.policy_restrict_to_staff_posts || currentUser.staff) {
      return {
        label: "discourse_policy.builder.attach",
        id: "insertPolicy",
        group: "insertions",
        icon: "file-signature",
        action: "insertPolicy",
      };
    }
  });

  api.modifyClass("controller:composer", {
    pluginId: "discourse-policy",
    actions: {
      insertPolicy() {
        showModal("policy-builder").setProperties({
          insertMode: true,
          post: null,
          toolbarEvent: this.toolbarEvent,
        });
      },
    },
  });
}

export default {
  name: "add-discourse-policy-builder",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    if (siteSettings.policy_enabled) {
      withPluginApi("0.8.7", (api) => initializePolicyBuilder(api, container));
    }
  },
};
