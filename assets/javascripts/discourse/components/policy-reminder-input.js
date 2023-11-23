import Component from "@glimmer/component";
import I18n from "I18n";

export default class PolicyReminderInput extends Component {
  validReminders = [
    {
      id: "daily",
      name: I18n.t("daily"),
    },
    {
      id: "weekly",
      name: I18n.t("weekly"),
    },
  ];
}
