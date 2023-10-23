import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";

function initializePolicyBuilder(api, container) {
  const currentUser = api.getCurrentUser();
  const siteSettings = container.lookup("site-settings:main");

  if (currentUser) {
    api.addComposerToolbarPopupMenuOption({
      label: "discourse_policy.builder.attach",
      icon: "file-signature",
      group: "insertions",
      action: (toolbarEvent) => {
        showModal("policy-builder").setProperties({
          insertMode: true,
          post: null,
          toolbarEvent,
        });
      },
      condition: () => {
        return (
          !siteSettings.policy_restrict_to_staff_posts || currentUser.staff
        );
      },
    });
  }
}

export default {
  name: "add-discourse-policy-builder",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    if (siteSettings.policy_enabled) {
      withPluginApi("1.15.0", (api) => initializePolicyBuilder(api, container));
    }
  },
};
