import Group from "discourse/models/group";
import Component from "@ember/component";
import { action, computed } from "@ember/object";

export default Component.extend({
  allGroups: null,
  group: null,
  onChangeGroup: null,

  init() {
    this._super(...arguments);

    this.set(
      "allGroups",
      Group.findAll().then((groups) => groups.filterBy("automatic", false))
    );
  },

  siteGroups: computed("site.groups", function () {
    return (this.site.groups || [])
      .map((g) => {
        if (g.id === 0) return; // prevents group "everyone" to be listed
        if (g.automatic) return;
        return g.name;
      })
      .filter(Boolean);
  }),

  @action
  onChange(values) {
    this.onChangeGroup && this.onChangeGroup(values);
  },
});
