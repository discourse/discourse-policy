import Component from "@ember/component";
import { action } from "@ember/object";

export default class PolicyBuilderForm extends Component {
  tagName = null;
  policy = null;
  onChange = null;

  @action
  changeValue(field, event) {
    this.onChange(field, event.target.value);
  }

  @action
  changeBoolValue(field, event) {
    this.onChange(field, event.target.checked);
  }
}
