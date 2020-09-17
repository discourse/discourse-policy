import { POLICY_SETTINGS } from "discourse/plugins/discourse-policy/lib/settings";
/*eslint no-bitwise:0 */

const rule = {
  tag: "policy",

  wrap: function (token, info) {
    if (!info.attrs.group) {
      return false;
    }

    token.attrs = [["class", "policy"]];

    POLICY_SETTINGS.forEach((element) => {
      const key = element.name.split("-");
      const value = info.attrs[key[key.length - 1]];
      if (key === "version") {
        token.attrs.push(["data-version", info.attrs.version || 1]);
      } else if (value) {
        token.attrs.push([`data-${element.name}`, value]);
      }
    });

    return true;
  },
};

export function setup(helper) {
  helper.whiteList(["div.policy"]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features.policy = !!siteSettings.policy_enabled;
  });

  helper.registerPlugin((md) => {
    md.block.bbcode.ruler.push("policy", rule);
  });
}
