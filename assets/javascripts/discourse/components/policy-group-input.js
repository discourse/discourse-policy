import Component from "@ember/component";
import { action, computed } from "@ember/object";

export default class PolicyGroupInput extends Component {
  tagName = null;
  groups = null;
  onChangeGroup = null;

  @computed("groups.[]")
  get selectedGroups() {
    return (this.groups || "").split(",").filter(Boolean);
  }

  @computed("site.groups.[]")
  get availableGroups() {
    return (this.site.groups || [])
      .map((g) => {
        if (g.id === 0) {
          return;
        } // prevents group "everyone" to be listed

        return g.name;
      })
      .filter(Boolean);
  }

  @action
  onChange(values) {
    if (this.onChangeGroup) {
      this.onChangeGroup(values.join(","));
    }
  }
}
