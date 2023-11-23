import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class PolicyBuilderForm extends Component {
  policy = null;

  @action
  changeValue(field, event) {
    this.args.onChange(field, event.target.value);
  }

  @action
  changeBoolValue(field, event) {
    this.args.onChange(field, event.target.checked);
  }
}
