/*eslint no-bitwise:0 */

const rule = {
  tag: 'policy',

  wrap: function(token, info) {
    if (!info.attrs.group) {
      return false;
    }

    token.attrs = [
      ['class', 'policy'],
      ['data-group', info.attrs.group],
      ['data-version', info.attrs.version || 1]
    ];

    if (info.attrs.reminder) {
      token.attrs.push(['data-reminder', info.attrs.reminder]);
    }

    return true;
  }
};

export function setup(helper) {
  helper.whiteList([
    'div.policy'
  ]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features.policy = !!siteSettings.policy_enabled;
  });


  helper.registerPlugin(md => {
    md.block.bbcode.ruler.push('policy', rule);
  });
}

