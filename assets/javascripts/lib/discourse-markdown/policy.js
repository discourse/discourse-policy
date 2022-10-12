/*eslint no-bitwise:0 */

const rule = {
  tag: "policy",

  wrap: function (token, info) {
    if (!info.attrs.group && !info.attrs.groups) {
      return false;
    }

    token.attrs = [["class", "policy"]];

    if (info.attrs["group"]) {
      token.attrs.push(["data-group", info.attrs.group]);
    }

    if (info.attrs["groups"]) {
      token.attrs.push(["data-groups", info.attrs.groups]);
    }

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

    if (info.attrs.private) {
      token.attrs.push(["data-private", info.attrs.private]);
    }

    if (info.attrs.email) {
      token.attrs.push(["data-send-email", info.attrs.email]);
    }

    return true;
  },
};

export function setup(helper) {
  helper.allowList(["div.policy"]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features.policy = !!siteSettings.policy_enabled;
  });

  helper.registerPlugin((md) => {
    md.block.bbcode.ruler.push("policy", rule);
  });
}
