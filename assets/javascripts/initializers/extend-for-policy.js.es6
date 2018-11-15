import { withPluginApi } from "discourse/lib/plugin-api";
import { renderAvatar } from "discourse/helpers/user-avatar";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { escapeExpression } from "discourse/lib/utilities";
import { iconHTML } from "discourse-common/lib/icon-library";
import TextLib from "discourse/lib/text";

let currentUser;

const SETTINGS = [
  { name: "group", visible: true },
  { name: "version", visible: true, optional: true },
  { name: "renew", visible: true, optional: true },
  { name: "reminder", optional: true },
  { name: "accept", optional: true },
  { name: "revoke", optional: true }
];

function initializePolicy(api) {
  currentUser = api.getCurrentUser();

  function loadPolicyUsers(users) {
    if (!users) {
      return [];
    }

    return users.map(u => {
      return renderAvatar(u, { imageSize: "tiny" });
    });
  }

  function render($policy, post) {
    $policy.find(".policy-footer").remove();

    let notAccepted = post.get("policy_not_accepted_by");
    let accepted = post.get("policy_accepted_by");

    if (!notAccepted) {
      notAccepted = [];
      post.set("policy_not_accepted_by", notAccepted);
    }

    if (!accepted) {
      accepted = [];
      post.set("policy_accepted_by", accepted);
    }

    const notAcceptedHtml = $(
      "<div class='users not-accepted'>" +
        loadPolicyUsers(notAccepted).join("") +
        "</div>"
    );
    const acceptedHtml = $(
      "<div class='users accepted'>" +
        loadPolicyUsers(accepted).join("") +
        "</div>"
    );

    let countNotAcceptedHtml = "";
    if (notAccepted.length > 0) {
      let title = escapeExpression(
        I18n.t("discourse_policy.not_accepted_tooltip")
      );
      if (accepted.length > 0) {
        countNotAcceptedHtml = "<span class='seperator'></span>";
      }
      let iconN = iconHTML("user-times", { class: "toggle-not-accepted" });
      countNotAcceptedHtml += `<a class='toggle toggle-not-accepted' title='${title}'>${iconN} ${
        notAccepted.length
      }</a>`;
    }

    let countAcceptedHtml = "";
    if (accepted.length > 0) {
      let title = escapeExpression(I18n.t("discourse_policy.accepted_tooltip"));
      let iconA = iconHTML("user", { class: "toggle-accepted" });
      countAcceptedHtml = `<a class='toggle toggle-accepted' title='${title}'>${iconA} ${
        accepted.length
      }</a>`;
    }
    const revokeText = escapeExpression(
      $policy.data("revoke") || I18n.t("discourse_policy.revoke_policy")
    );
    const acceptText = escapeExpression(
      $policy.data("accept") || I18n.t("discourse_policy.accept_policy")
    );
    const $footer = $('<div class="policy-footer"></div>');
    $footer
      .append(
        `<button class='btn btn-danger revoke btn-revoke-policy'>${revokeText}</button>`
      )
      .append(
        `<button class='btn btn-primary accept btn-accept-policy'>${acceptText}</button>`
      );
    $('<div class="user-lists"></div>')
      .appendTo($footer)
      .append(countAcceptedHtml)
      .append(acceptedHtml)
      .append(countNotAcceptedHtml)
      .append(notAcceptedHtml);

    if ($policy.find(".policy-body").length === 0) {
      $policy.wrapInner("<div class='policy-body'></div>");
    }

    $policy.append($footer);

    let currentAccepted, currentNotAccepted;

    if (currentUser) {
      currentAccepted = accepted.any(u => u.id === currentUser.id);
      currentNotAccepted = notAccepted.any(u => u.id === currentUser.id);
    }

    $policy.find(".btn.accept, .btn.revoke").hide();

    if ($policy.attr("data-show-unaccepted")) {
      $policy.find(".users.accepted").hide();
    } else {
      $policy.find(".users.not-accepted").hide();
    }

    if (currentAccepted) {
      $policy.find(".btn.revoke").show();
    }

    if (currentNotAccepted) {
      $policy.find(".btn.accept").show();
    }

    $policy.find(".policy-settings").remove();
    const $policySettings = $(`<div class="policy-settings"></div>`);
    $policy.append($policySettings);
    const existingSettings = _extractSettingsFromCookedContainer($policy);
    const currentUserCanManagePolicy =
      currentUser.staff || currentUser.id === post.user_id;
    if (currentUserCanManagePolicy) {
      _attachEditSettingsUI($policy, $policySettings, existingSettings, post);
    } else {
      _attachReadSettingsUI($policy, $policySettings, existingSettings);
    }
  }

  function _attachEditSettingsUI(
    $policy,
    $policySettings,
    existingSettings,
    post
  ) {
    const $editPolicySettingsBtn = $(
      `<button class="btn no-text btn-default edit-policy-settings-btn">${iconHTML(
        "gear"
      )}</button>`
    );
    $policy.append($editPolicySettingsBtn);

    const $settingsList = $(`<div class="settings-list"></div>`);

    $policy.find(".save-policy-settings-btn").remove();
    const $savePolicyBtn = $(
      `<button class="btn btn-primary save-policy-settings-btn">${I18n.t(
        "save"
      )}</button>`
    );

    $policySettings.append($settingsList).append($savePolicyBtn);

    SETTINGS.forEach(setting => {
      _attachSettingInput(
        $settingsList,
        setting,
        existingSettings[setting.name]
      );
    });

    $policy
      .on("click", ".edit-policy-settings-btn", () => {
        if ($policySettings.css("display") === "flex") {
          $policySettings.hide();
        } else {
          $policySettings.show().css("display", "flex");
        }
      })
      .on("click", ".save-policy-settings-btn", () =>
        _saveSettings($settingsList, existingSettings, post).then(() =>
          $policySettings.hide()
        )
      );
  }

  function _attachReadSettingsUI($policy, $policySettings, existingSettings) {
    $policy.find(".see-policy-settings-btn").remove();
    const $seePolicySettingsBtn = $(
      `<button class="btn no-text btn-default see-policy-settings-btn">${iconHTML(
        "info"
      )}</button>`
    );

    $policy
      .append($seePolicySettingsBtn)
      .on("click", $seePolicySettingsBtn, () => {
        if ($policySettings.css("display") === "flex") {
          $policySettings.hide().empty();
        } else {
          const settingsString = SETTINGS.filter(s => s.visible)
            .map(s => `${s.name}: ${existingSettings[s.name]}`)
            .join(", ");

          $policySettings.html(`<span class="visible-settings"></span>`);
          $policySettings.find(".visible-settings").text(settingsString);
          $policySettings.show().css("display", "flex");
        }
      });
  }

  function _saveSettings($list, existingSettings, post) {
    const newSettings = _getSettingsValueFromForm($list);
    const endpoint = `/posts/${post.id}`;
    const options = { type: "GET", cache: false };
    return ajax(endpoint, options).then(result => {
      const raw = result.raw;
      const newRaw = _replaceSettingsInRaw(existingSettings, newSettings, raw);

      if (newRaw) {
        const props = {
          raw: newRaw,
          edit_reason: I18n.t("discourse_policy.edit_reason")
        };

        return TextLib.cookAsync(raw).then(cooked => {
          props.cooked = cooked.string;
          post.save(props);
        });
      }
    });
  }

  function _replaceSettingsInRaw(existingSettings, newSettings, raw) {
    let settingReplaced = false;

    const policyRegex = new RegExp(`\\[policy\\s(.*?)\\]`, "m");
    const policyMatches = raw.match(policyRegex);
    let policyString = "";
    if (policyMatches && policyMatches[1]) {
      // sanitizing any xx=zz, xx='zz', xx="zz" into xx="zz"
      // it makes regex way easier
      policyString = policyMatches[1]
        .replace(/(.*?\w+=)'(.*?)'(.*?)/gm, `$1"$2"$3`)
        .replace(/(.*?\w+=)([\w]+)(.*?)/gm, `$1"$2"$3`);
    }

    SETTINGS.forEach(setting => {
      const existingSetting = existingSettings[setting.name];
      const newSetting = newSettings[setting.name];

      if (existingSetting === newSetting) return;

      settingReplaced = true;

      if (!existingSetting) {
        policyString = `${policyString} ${setting.name}="${newSetting}"`;
      } else if (!newSetting) {
        if (setting.optional) {
          const regexp = new RegExp(`(\\s?${setting.name}=".*?")`, "gm");
          policyString = policyString.replace(regexp, "");
        }
      } else {
        const regexp = new RegExp(`(${setting.name}=)".*?"`, "gm");
        policyString = policyString.replace(regexp, `$1"${newSetting}"`);
      }

      raw = raw.replace(policyRegex, `[policy ${policyString}]`);
    });

    return settingReplaced ? raw : false;
  }

  function _getSettingsValueFromForm($form) {
    let extractedSettings = {};
    SETTINGS.forEach(setting => {
      extractedSettings[setting.name] = $form
        .find(`#policy-setting-${setting.name}`)
        .val();
    });
    return extractedSettings;
  }

  function _extractSettingsFromCookedContainer($cooked) {
    let extractedSettings = {};
    SETTINGS.forEach(setting => {
      extractedSettings[setting.name] =
        $cooked.attr(`data-${setting.name}`) || "";
    });
    return extractedSettings;
  }

  function _attachSettingInput($container, setting, value) {
    const $label = $(`<span class="policy-setting-name">${setting.name}</span>`);
    const $input = $(
      `<input class="input policy-setting-value" id="policy-setting-${
        setting.name
      }" value="${value}" placeholder="${
        setting.optional ? "optional" : "required"
      }">`
    );
    const $setting = $(`<div class="setting"></div>`);

    $container.append($setting);
    $setting.append($label).append($input);
  }

  function attachPolicy($elem, helper) {
    const $policy = $elem.find(".policy");

    if ($policy.length === 0) {
      return;
    }

    render($policy, helper.getModel());
  }

  function revokePolicy($policy, post) {
    let notAccepted = post.get("policy_not_accepted_by");
    let accepted = post.get("policy_accepted_by");

    let elem = accepted.findBy("id", currentUser.id);

    if (elem) {
      accepted.removeObject(elem);
      notAccepted.addObject(elem);
      render($policy, post);
    }
    ajax("/policy/unaccept", {
      type: "put",
      data: {
        post_id: post.get("id")
      }
    }).catch(popupAjaxError);
    return false;
  }

  function acceptPolicy($policy, post) {
    let notAccepted = post.get("policy_not_accepted_by");
    let accepted = post.get("policy_accepted_by");

    let elem = notAccepted.findBy("id", currentUser.id);

    if (elem) {
      notAccepted.removeObject(elem);
      accepted.addObject(elem);
      render($policy, post);
    }
    ajax("/policy/accept", {
      type: "put",
      data: {
        post_id: post.get("id")
      }
    }).catch(popupAjaxError);
    return false;
  }

  function policyChanged(topicsController, message) {
    const stream = topicsController.get("model.postStream");
    const post = stream.findLoadedPost(message.id);

    const $policy = $(`article[data-post-id=${message.id}] .policy`);

    if (post && $policy.length > 0) {
      ajax(`/posts/${message.id}.json`).then(data => {
        post.set("policy_accepted_by", data.policy_accepted_by || []);
        post.set("policy_not_accepted_by", data.policy_not_accepted_by || []);
        render($policy, post);
      });
    }
  }

  api.decorateCooked(attachPolicy, { onlyStream: true });
  api.registerCustomPostMessageCallback("policy_change", policyChanged);

  api.modifyClass("component:discourse-topic", {
    click: function(arg) {
      const $target = $(arg.target);

      const findPost = () => {
        const postId = $target.closest("article").attr("data-post-id");
        return this.get("postStream").findLoadedPost(postId);
      };

      if ($target.hasClass("btn-accept-policy")) {
        const $policy = $target.closest(".policy");
        const post = findPost();

        acceptPolicy($policy, post);

        return false;
      }

      if ($target.hasClass("btn-revoke-policy")) {
        const $policy = $target.closest(".policy");
        const post = findPost();

        revokePolicy($policy, post);

        return false;
      }

      if ($target.hasClass("toggle-accepted")) {
        const $policy = $target.closest(".policy");
        const post = findPost();

        $policy.removeAttr("data-show-unaccepted");

        render($policy, post);
      }

      if ($target.hasClass("toggle-not-accepted")) {
        const $policy = $target.closest(".policy");
        const post = findPost();

        $policy.attr("data-show-unaccepted", "true");

        render($policy, post);
      }

      this._super(arg);
    }
  });
}

export default {
  name: "extend-for-policy",

  initialize() {
    withPluginApi("0.8.7", initializePolicy);
  }
};
