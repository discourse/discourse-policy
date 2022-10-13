import { withPluginApi } from "discourse/lib/plugin-api";

const SEND_EMAIL_NOTIFICATIONS_FIELD = "send_email_notifications";

export default {
  name: "policy-user-options",

  initialize(container) {
    withPluginApi("0.8.7", (api) => {
      const siteSettings = container.lookup("site-settings:main");
      if (siteSettings.policy_enabled) {
        api.addSaveableUserOptionField(SEND_EMAIL_NOTIFICATIONS_FIELD);
      }
    });
  },
};
