import Component from "@glimmer/component";
import { action, computed } from "@ember/object";
import { inject as service } from "@ember/service";

export default class PolicyGroupInput extends Component {
  @service site;

  get selectedGroups() {
    return (this.args.groups || "").split(",").filter(Boolean);
  }

  @computed("site.groups.[]")
  get availableGroups() {
    return (this.site.groups || [])
      .map((g) => {
        // prevents group "everyone" to be listed
        return g.id === 0 ? null : g.name;
      })
      .filter(Boolean);
  }

  @action
  onChange(values) {
    this.args.onChangeGroup?.(values.join(","));
  }
}
