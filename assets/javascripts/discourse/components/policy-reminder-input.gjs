import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

const VALID_REMINDERS = [
  {
    id: "daily",
    name: i18n("daily"),
  },
  {
    id: "weekly",
    name: i18n("weekly"),
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
