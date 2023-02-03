import EmberObject from "@ember/object";
import I18n from "I18n";
import { withPluginApi } from "discourse/lib/plugin-api";
import { escapeExpression } from "discourse/lib/utilities";
import { hbs } from "ember-cli-htmlbars";

const SETTINGS = [
  { name: "groups" },
  { name: "version" },
  { name: "renew" },
  {
    name: "renew-start",
    camelName: "renewStart",
  },
  { name: "reminder" },
  {
    name: "accept",
    default: I18n.t("discourse_policy.accept_policy"),
    escape: true,
  },
  {
    name: "revoke",
    default: I18n.t("discourse_policy.revoke_policy"),
    escape: true,
  },
];

function initializePolicy(api) {
  function _buildPolicyAttributes(policy) {
    const form = {};
    SETTINGS.forEach((setting) => {
      form[setting.name] =
        policy.dataset[setting.camelName || setting.name] ||
        setting.default ||
        "";

      if (setting.escape) {
        form[setting.name] = escapeExpression(form[setting.name]);
      }
    });

    if (!form.version || parseInt(form.version, 10) < 1) {
      form.version = 1;
    }

    form.private = policy.dataset.private === "true";

    return EmberObject.create(form);
  }

  function attachPolicy(cooked, helper) {
    const policy = cooked.querySelector(".policy");

    if (!policy) {
      return;
    }

    policy.innerHTML = `<div class="policy-body">${policy.innerHTML}</div>`;

    if (!helper) {
      // if no helper it means we are decorating the preview, make it clear it's a policy
      const policyPreview = document.createElement("div");
      policyPreview.classList.add("policy-preview");
      policyPreview.innerText = I18n.t("discourse_policy.title");
      policy.prepend(policyPreview);
      return;
    }

    const post = helper.getModel();

    helper.renderGlimmer(
      policy,
      hbs`<PostPolicy @post={{@data.post}} @policy={{@data.policy}} />`,
      { post, policy: _buildPolicyAttributes(policy) }
    );
  }

  api.decorateCookedElement(attachPolicy, {
    onlyStream: false,
    id: "discourse-policy",
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
