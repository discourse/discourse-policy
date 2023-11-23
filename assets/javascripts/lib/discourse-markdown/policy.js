const rule = {
  tag: "policy",

  wrap(token, info) {
    if (!info.attrs.group && !info.attrs.groups) {
      return false;
    }

    token.attrs = [
      ["class", "policy"],
      info.attrs.group && ["data-group", info.attrs.group],
      info.attrs.groups && ["data-groups", info.attrs.groups],
      ["data-version", info.attrs.version || 1],
      info.attrs.renew && ["data-renew", info.attrs.renew],
      info.attrs.reminder && ["data-reminder", info.attrs.reminder],
      info.attrs.accept && ["data-accept", info.attrs.accept],
      info.attrs.revoke && ["data-revoke", info.attrs.revoke],
      info.attrs.start && ["data-renew-start", info.attrs.start],
      info.attrs.private && ["data-private", info.attrs.private],
    ].filter(Boolean);

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
