import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";

function initializePolicyBuilder(api) {
  const currentUser = api.getCurrentUser();

  api.addToolbarPopupMenuOptionsCallback(() => {
    if (!currentUser || !currentUser.can_create_discourse_post_event) {
      return;
    }

    return {
      label: "discourse_policy.builder.attach",
      id: "insertPolicy",
      group: "insertions",
      icon: "file-signature",
      action: "insertPolicy",
    };
  });

  api.modifyClass("controller:composer", {
    actions: {
      insertPolicy() {
        showModal("policy-builder").setProperties({
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
      withPluginApi("0.8.7", initializePolicyBuilder);
    }
  },
};
