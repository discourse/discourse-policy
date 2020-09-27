import EmberObject from "@ember/object";
import I18n from "I18n";
import { withPluginApi } from "discourse/lib/plugin-api";
import { escapeExpression } from "discourse/lib/utilities";

const SETTINGS = [
  { name: "group", visible: true },
  { name: "version", visible: true, optional: true },
  { name: "renew", visible: true, optional: true },
  {
    name: "renew-start",
    camelName: "renewStart",
    visible: true,
    optional: true,
  },
  { name: "reminder", optional: true },
  { name: "accept", optional: true },
  { name: "revoke", optional: true },
];

function initializePolicy(api) {
  function _buildForm(policy) {
    const form = {};
    SETTINGS.forEach((setting) => {
      form[setting.name] =
        policy.dataset[setting.camelName || setting.name] || "";
    });

    if (!form.version || parseInt(form.version, 10) < 1) {
      form.version = 1;
    }

    return EmberObject.create(form);
  }

  function attachPolicy(cooked, helper) {
    const policy = cooked.querySelector(".policy");

    if (!policy) {
      return;
    }

    policy.innerHTML = `<div class="policy-body">${policy.innerHTML}</div>`;

    if (!helper) {
      return;
    }

    const post = helper.getModel();

    const component = api.container.owner
      .factoryFor("component:post-policy")
      .create({
        post,
        form: _buildForm(policy),
        options: {
          revokeText: escapeExpression(
            policy.dataset.revoke || I18n.t("discourse_policy.revoke_policy")
          ),
          acceptText: escapeExpression(
            policy.dataset.accept || I18n.t("discourse_policy.accept_policy")
          ),
        },
      });

    component.renderer.appendTo(component, policy);
  }

  api.decorateCookedElement(attachPolicy, {
    onlyStream: true,
    id: "discouse-policy",
  });

  api.registerCustomPostMessageCallback(
    "policy_change",
    (controller, message) => {
      controller.appEvents.trigger("policy:changed", { controller, message });
    }
  );
}

export default {
  name: "extend-for-policy",

  initialize() {
    withPluginApi("0.8.7", initializePolicy);
  },
};
