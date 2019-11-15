/*eslint no-bitwise:0 */

const rule = {
  tag: "policy",

  wrap: function(token, info) {
    if (!info.attrs.group) {
      return false;
    }

    token.attrs = [
      ["class", "policy"],
      ["data-group", info.attrs.group]
    ];

    token.attrs.push(["data-version", info.attrs.version || 1]);

    if (info.attrs["renew"]) {
      token.attrs.push(["data-renew", info.attrs.renew]);
    }

    if (info.attrs.reminder) {
      token.attrs.push(["data-reminder", info.attrs.reminder]);
    }

    if (info.attrs.accept) {
      token.attrs.push(["data-accept", info.attrs.accept]);
    }

    if (info.attrs.revoke) {
      token.attrs.push(["data-revoke", info.attrs.revoke]);
    }

    if (info.attrs.start) {
      token.attrs.push(["data-renew-start", info.attrs.start]);
    }

    return true;
  }
};

export function setup(helper) {
  helper.whiteList(["div.policy"]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features.policy = !!siteSettings.policy_enabled;
  });

  helper.registerPlugin(md => {
    md.block.bbcode.ruler.push("policy", rule);
  });
}
