import EmberObject from "@ember/object";
import showModal from "discourse/lib/show-modal";
import I18n from "I18n";
import getURL from "discourse-common/lib/get-url";
import { withPluginApi } from "discourse/lib/plugin-api";
import { renderAvatar } from "discourse/helpers/user-avatar";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { escapeExpression } from "discourse/lib/utilities";
import { iconHTML } from "discourse-common/lib/icon-library";

let currentUser;

const SETTINGS = [
  { name: "group", visible: true },
  { name: "version", visible: true, optional: true },
  { name: "renew", visible: true, optional: true },
  { name: "renew-start", visible: true, optional: true },
  { name: "reminder", optional: true },
  { name: "accept", optional: true },
  { name: "revoke", optional: true },
];

function initializePolicy(api) {
  currentUser = api.getCurrentUser();

  function loadPolicyUsers(users) {
    if (!users) {
      return [];
    }

    return users.map((u) => {
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
        countNotAcceptedHtml = "<div class='seperator'></div>";
      }
      let iconN = iconHTML("user-times");
      countNotAcceptedHtml += `<a class='toggle toggle-not-accepted' title='${title}'>
                                 <span class="user-count">
                                   ${notAccepted.length}
                                 </span>
                                 ${iconN}
                               </a>`;
    }

    let countAcceptedHtml = "";
    if (accepted.length > 0) {
      let title = escapeExpression(I18n.t("discourse_policy.accepted_tooltip"));
      let iconA = iconHTML("user-check");
      countAcceptedHtml = `<a class='toggle toggle-accepted' title='${title}'>
                             <span class="user-count">
                               ${accepted.length}
                             </span>
                             ${iconA}
                           </a>`;
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
      currentAccepted = accepted.any((u) => u.id === currentUser.id);
      currentNotAccepted = notAccepted.any((u) => u.id === currentUser.id);
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

    const currentUserCanManagePolicy =
      currentUser.staff || currentUser.id === post.user_id;
    if (currentUserCanManagePolicy) {
      _attachEditSettingsUI(
        $policy,
        $policySettings,
        post,
        _buildForm($policy)
      );
    }
  }

  function _buildForm($policy) {
    const form = {};
    SETTINGS.forEach((setting) => {
      form[setting.name] = $policy.attr(`data-${setting.name}`) || "";
    });

    if (!form.version || parseInt(form.version, 10) < 1) {
      form.version = 1;
    }

    return EmberObject.create(form);
  }

  function _attachEditSettingsUI($policy, $policySettings, post, form) {
    const $editPolicySettingsBtn = $(
      `<button class="btn no-text btn-default edit-policy-settings-btn">${iconHTML(
        "cog"
      )}</button>`
    );
    $policy.append($editPolicySettingsBtn);

    $policy.on("click", ".edit-policy-settings-btn", () => {
      showModal("policy-builder").setProperties({
        insertMode: false,
        post,
        form,
      });
    });
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

    const endpoint = getURL("/policy/unaccept");
    ajax(endpoint, {
      type: "put",
      data: {
        post_id: post.get("id"),
      },
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
    const endpoint = getURL("/policy/accept");
    ajax(endpoint, {
      type: "put",
      data: {
        post_id: post.get("id"),
      },
    }).catch(popupAjaxError);
    return false;
  }

  function policyChanged(topicsController, message) {
    const stream = topicsController.get("model.postStream");
    const post = stream.findLoadedPost(message.id);

    const $policy = $(`article[data-post-id=${message.id}] .policy`);

    if (post && $policy.length > 0) {
      const endpoint = getURL(`/posts/${message.id}.json`);
      ajax(endpoint).then((data) => {
        post.set("policy_accepted_by", data.policy_accepted_by || []);
        post.set("policy_not_accepted_by", data.policy_not_accepted_by || []);
        render($policy, post);
      });
    }
  }

  api.decorateCooked(attachPolicy, { onlyStream: true, id: "discouse-policy" });
  api.registerCustomPostMessageCallback("policy_change", policyChanged);

  api.attachWidgetAction("post", "click", function (arg) {
    const $target = $(arg.target);
    const post = this.model;

    if ($target.hasClass("btn-accept-policy")) {
      const $policy = $target.closest(".policy");

      acceptPolicy($policy, post);

      return false;
    }

    if ($target.hasClass("btn-revoke-policy")) {
      const $policy = $target.closest(".policy");

      revokePolicy($policy, post);

      return false;
    }

    if (
      $target.hasClass("toggle-accepted") ||
      $target.parent().hasClass("toggle-accepted")
    ) {
      const $policy = $target.closest(".policy");

      $policy.removeAttr("data-show-unaccepted");

      render($policy, post);
    }

    if (
      $target.hasClass("toggle-not-accepted") ||
      $target.parent().hasClass("toggle-not-accepted")
    ) {
      const $policy = $target.closest(".policy");

      $policy.attr("data-show-unaccepted", "true");

      render($policy, post);
    }
  });
}

export default {
  name: "extend-for-policy",

  initialize() {
    withPluginApi("0.8.7", initializePolicy);
  },
};
