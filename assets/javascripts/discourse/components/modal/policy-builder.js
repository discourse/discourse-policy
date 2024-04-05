import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action, set } from "@ember/object";
import { isBlank, isPresent } from "@ember/utils";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import { cook } from "discourse/lib/text";
import I18n from "I18n";

export default class PolicyBuilder extends Component {
  @tracked isSaving = false;
  @tracked flash;
  policy =
    this.args.model.policy ||
    new TrackedObject({ reminder: "daily", version: 1 });

  @action
  onChangeFormField(field, value) {
    set(this.policy, field, value);
  }

  @action
  insertPolicy() {
    if (!this.validateForm()) {
      return;
    }

    this.args.model.toolbarEvent?.addText(
      `\n\n[policy ${this.markdownParams}]\n${I18n.t(
        "discourse_policy.accept_policy_template"
      )}\n[/policy]\n\n`
    );
    this.args.closeModal();
  }

  @action
  async updatePolicy() {
    if (!this.validateForm()) {
      return;
    }

    this.isSaving = true;

    try {
      const result = await ajax(`/posts/${this.args.model.post.id}`);

      const raw = result.raw;
      const newRaw = this.replaceRaw(raw);

      if (newRaw) {
        const props = {
          raw: newRaw,
          edit_reason: I18n.t("discourse_policy.edit_reason"),
        };

        const cooked = await cook(raw);

        props.cooked = cooked.string;
        this.args.model.post.save(props);
      }
    } finally {
      this.isSaving = false;
      this.args.closeModal();
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
      this.flash = I18n.t("discourse_policy.builder.errors.group");
      return false;
    }

    if (isBlank(this.policy.version)) {
      this.flash = I18n.t("discourse_policy.builder.errors.version");
      return false;
    }

    return true;
  }
}
