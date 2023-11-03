import { isPresent } from "@ember/utils";
import I18n from "I18n";
import { cook } from "discourse/lib/text";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import Controller from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import getURL from "discourse-common/lib/get-url";
import { ajax } from "discourse/lib/ajax";

export default Controller.extend(ModalFunctionality, {
  toolbarEvent: null,
  post: null,
  isSaving: false,
  insertMode: true,

  onShow() {
    if (!this.policy) {
      this.set("policy", EmberObject.create({ reminder: "daily", version: 1 }));
    }
  },

  onClose() {
    this.set("policy", null);
  },

  @action
  onChangeFormField(field, value) {
    this.policy?.set(field, value);
  },

  @action
  insertPolicy() {
    if (!this._validateForm(this.policy)) {
      return;
    }

    const markdownParams = this._buildParams(this.policy);
    this.toolbarEvent.addText(
      `\n\n[policy ${markdownParams.join(" ")}]\n${I18n.t(
        "discourse_policy.accept_policy_template"
      )}\n[/policy]\n\n`
    );
    this.send("closeModal");
  },

  @action
  updatePolicy() {
    if (!this._validateForm(this.policy)) {
      return;
    }

    this.set("isSaving", true);

    const endpoint = getURL(`/posts/${this.post.id}`);
    const options = { type: "GET", cache: false };

    return ajax(endpoint, options)
      .then((result) => {
        const raw = result.raw;
        const newRaw = this._replaceRaw(this.policy, raw);

        if (newRaw) {
          const props = {
            raw: newRaw,
            edit_reason: I18n.t("discourse_policy.edit_reason"),
          };

          return cook(raw).then((cooked) => {
            props.cooked = cooked.string;
            this.post.save(props);
          });
        }
      })
      .finally(() => {
        this.set("isSaving", false);
        this.send("closeModal");
      });
  },

  _buildParams(policy) {
    const markdownParams = [];
    Object.keys(policy).forEach((key) => {
      const value = policy[key];

      if (value && isPresent(value)) {
        markdownParams.push(`${key}="${value}"`);
      }
    });
    return markdownParams;
  },

  _replaceRaw(policy, raw) {
    const policyRegex = new RegExp(`\\[policy\\s(.*?)\\]`, "m");
    const policyMatches = raw.match(policyRegex);

    if (policyMatches && policyMatches[1]) {
      const markdownParams = this._buildParams(policy);
      return raw.replace(policyRegex, `[policy ${markdownParams.join(" ")}]`);
    }

    return false;
  },

  _validateForm(policy) {
    if (!policy.groups || !isPresent(policy.groups)) {
      this.flash(I18n.t("discourse_policy.builder.errors.group"), "error");
      return false;
    }

    if (!policy.version || !isPresent(policy.version)) {
      this.flash(I18n.t("discourse_policy.builder.errors.version"), "error");
      return false;
    }

    return true;
  },
});
