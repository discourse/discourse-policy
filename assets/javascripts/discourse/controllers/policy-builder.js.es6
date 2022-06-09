import { isPresent } from "@ember/utils";
import I18n from "I18n";
import TextLib from "discourse/lib/text";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import Controller from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import getURL from "discourse-common/lib/get-url";
import { ajax } from "discourse/lib/ajax";

export default Controller.extend(ModalFunctionality, {
  toolbarEvent: null,
  form: null,
  post: null,
  isSaving: false,
  insertMode: true,

  onShow() {
    if (!this.form) {
      this.set("form", EmberObject.create({ reminder: "daily", version: 1 }));
    }
  },

  onClose() {
    this.set("form", null);
  },

  @action
  insertPolicy() {
    if (!this._validateForm(this.form)) {
      return;
    }

    const markdownParams = this._buildParams(this.form);
    this.toolbarEvent.addText(
      `\n\n[policy ${markdownParams.join(" ")}]\n[/policy]\n\n`
    );
    this.send("closeModal");
  },

  @action
  updatePolicy() {
    if (!this._validateForm(this.form)) {
      return;
    }

    this.set("isSaving", true);

    const endpoint = getURL(`/posts/${this.post.id}`);
    const options = { type: "GET", cache: false };

    return ajax(endpoint, options)
      .then((result) => {
        const raw = result.raw;
        const newRaw = this._replaceRaw(this.form, raw);

        if (newRaw) {
          const props = {
            raw: newRaw,
            edit_reason: I18n.t("discourse_policy.edit_reason"),
          };

          return TextLib.cookAsync(raw).then((cooked) => {
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

  @action
  onChangeRenewStartChange(value) {
    this.form.set("renew-start", value);
  },

  _buildParams(form) {
    const markdownParams = [];
    Object.keys(form).forEach((key) => {
      const value = form[key];

      if (value && isPresent(value)) {
        markdownParams.push(`${key}="${value}"`);
      }
    });
    return markdownParams;
  },

  _replaceRaw(form, raw) {
    const policyRegex = new RegExp(`\\[policy\\s(.*?)\\]`, "m");
    const policyMatches = raw.match(policyRegex);

    if (policyMatches && policyMatches[1]) {
      const markdownParams = this._buildParams(form);
      return raw.replace(policyRegex, `[policy ${markdownParams.join(" ")}]`);
    }

    return false;
  },

  _validateForm(form) {
    if (!form.groups || !isPresent(form.groups)) {
      this.flash(I18n.t("discourse_policy.builder.errors.group"), "error");
      return false;
    }

    if (!form.version || !isPresent(form.version)) {
      this.flash(I18n.t("discourse_policy.builder.errors.version"), "error");
      return false;
    }

    return true;
  },
});
