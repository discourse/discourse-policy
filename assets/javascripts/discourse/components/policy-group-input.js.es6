import Component from "@ember/component";
import { action, computed } from "@ember/object";

export default Component.extend({
  group: null,
  onChangeGroup: null,

  siteGroups: computed("site.groups", function () {
    return (this.site.groups || [])
      .map((g) => {
        if (g.id === 0) {
          return;
        } // prevents group "everyone" to be listed

        return g.name;
      })
      .filter(Boolean);
  }),

  @action
  onChange(values) {
    if (this.onChangeGroup) {
      this.onChangeGroup(values);
    }
  },
});
