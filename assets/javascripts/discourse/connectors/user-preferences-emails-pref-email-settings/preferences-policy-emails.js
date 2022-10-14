import I18n from "I18n";

export default {
  setupComponent(args, component) {
    const EMAIL_FREQUENCY_OPTIONS = [
      { name: I18n.t(`discourse_policy.preferences.policy_emails.email_frequency_options.never`), value: "never" },
      { name: I18n.t(`discourse_policy.preferences.policy_emails.email_frequency_options.when_away`), value: "when_away" },
      { name: I18n.t(`discourse_policy.preferences.policy_emails.email_frequency_options.always`), value: "always" },
    ];
    component.set('policyEmailFrequencyOptions', EMAIL_FREQUENCY_OPTIONS);
  }
}
