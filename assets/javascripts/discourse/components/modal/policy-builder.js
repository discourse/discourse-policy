import { isBlank, isPresent } from "@ember/utils";
import I18n from "I18n";
import { cook } from "discourse/lib/text";
import Component from "@ember/component";
import EmberObject, { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class PolicyBuilder extends Component {
  isSaving = false;
  policy;
  flash;

  init() {
    super.init(...arguments);
    this.set(
      "policy",
      this.model.policy || EmberObject.create({ reminder: "daily", version: 1 })
    );
  }

  @action
  onChangeFormField(field, value) {
    this.policy.set(field, value);
  }

  @action
  insertPolicy() {
    if (!this.validateForm()) {
      return;
    }

    this.model.toolbarEvent?.addText(
      `\n\n[policy ${this.markdownParams}]\n${I18n.t(
        "discourse_policy.accept_policy_template"
      )}\n[/policy]\n\n`
    );
    this.closeModal();
  }

  @action
  async updatePolicy() {
    if (!this.validateForm()) {
      return;
    }

    this.set("isSaving", true);

    try {
      const result = await ajax(`/posts/${this.model.post.id}`);

      const raw = result.raw;
      const newRaw = this.replaceRaw(raw);

      if (newRaw) {
        const props = {
          raw: newRaw,
          edit_reason: I18n.t("discourse_policy.edit_reason"),
        };

        const cooked = await cook(raw);

        props.cooked = cooked.string;
        this.model.post.save(props);
      }
    } finally {
      this.set("isSaving", false);
      this.closeModal();
    }
  }

  get markdownParams() {
    const markdownParams = [];
    for (const [key, value] of Object.entries(this.policy)) {
      if (isPresent(value)) {
        markdownParams.push(`${key}="${value}"`);
      }
    }
    return markdownParams.join(" ");
  }

  replaceRaw(raw) {
    const policyRegex = new RegExp(`\\[policy\\s(.*?)\\]`, "m");
    const policyMatches = raw.match(policyRegex);

    if (policyMatches?.[1]) {
      return raw.replace(policyRegex, `[policy ${this.markdownParams}]`);
    }

    return false;
  }

  validateForm() {
    if (isBlank(this.policy.groups)) {
      this.set("flash", I18n.t("discourse_policy.builder.errors.group"));
      return false;
    }

    if (isBlank(this.policy.version)) {
      this.set("flash", I18n.t("discourse_policy.builder.errors.version"));
      return false;
    }

    return true;
  }
}
