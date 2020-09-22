import Component from "@ember/component";
import I18n from "I18n";

const VALID_REMINDERS = [
  {
    id: "daily",
    name: I18n.t("daily"),
  },
  {
    id: "weekly",
    name: I18n.t("weekly"),
  },
];

export default Component.extend({
  reminder: null,
  onChangeReminder: null,
  validReminders: VALID_REMINDERS,
});
