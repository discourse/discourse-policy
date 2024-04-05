import I18n from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

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

const PolicyReminderInput = <template>
  <ComboBox
    @value={{@reminder}}
    @content={{VALID_REMINDERS}}
    @onChange={{@onChangeReminder}}
  />
</template>;

export default PolicyReminderInput;
