import { withPluginApi } from 'discourse/lib/plugin-api';
import { renderAvatar } from 'discourse/helpers/user-avatar';
import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';

let currentUser;

function initializePolicy(api) {

  currentUser = api.getCurrentUser();

  function loadPolicyUsers(users) {
    if (!users) {
      return [];
    }

    return users.map(u => {
      return renderAvatar(u, { imageSize: 'tiny' });
    });

  }

  function policyChanged(topicsController, message) {
    console.log(message);
    console.log(topicsController);
  }

  function attachPolicy( $elem, helper ) {

    const $policy = $elem.find('.policy');

    if ($policy.length === 0) {
      return;
    }

    $policy.find('.policy-header, .policy-footer').remove();

    const post = helper.getModel();


    let notAccepted = post.get('policy_not_accepted_by');
    let accepted = post.get('policy_accepted_by');

    if (!notAccepted) {
      notAccepted = [];
      post.set('policy_not_accepted_by', notAccepted);
    }

    if (!accepted) {
      accepted = [];
      post.set('policy_accepted_by', accepted);
    }

    const notAcceptedHtml = $("<div class='extra-elem users not-accepted'>" + loadPolicyUsers(notAccepted).join('') + "</div>");
    const acceptedHtml = $("<div class='extra-elem users accepted'>" + loadPolicyUsers(accepted).join('') + "</div>");

    let countNotAcceptedHtml = "";
    if (notAccepted.length > 0) {
      countNotAcceptedHtml = `<a class='extra-elem toggle not-accepted'><i class='fa fa-user-times'></i>${notAccepted.length}</a>`;
    }

    const $header = $('<div class="policy-header"></div>');
    $header.append(countNotAcceptedHtml);

    const $footer = $('<div class="policy-footer"></div>');
    $footer
      .append(acceptedHtml)
      .append(notAcceptedHtml)
      .append("<button class='extra-elem btn btn-danger revoke'>Revoke Policy</button>")
      .append("<button class='extra-elem btn btn-primary accept'>Accept Policy</button>");

    $policy
      .prepend($header)
      .append($footer);

    let currentAccepted, currentNotAccepted;

    if (currentUser) {
      currentAccepted = accepted.any(u => u.id === currentUser.id);
      currentNotAccepted = notAccepted.any(u => u.id === currentUser.id);
    }

    $policy.find('.btn.accept, .btn.revoke, .users.not-accepted').hide();

    if (currentAccepted) {
       $policy.find('.btn.revoke').show();
    }

    if (currentNotAccepted) {
       $policy.find('.btn.accept').show();
    }

    $policy.find('.toggle.not-accepted').on('click', () => {

      $policy.find('.users.not-accepted').show();
      $policy.find('.users.accepted').hide();

      return false;
    });

    const $acceptButton = $policy.find('.btn.accept');
    $acceptButton.on('click', function() {
      let elem = notAccepted.findBy('id', currentUser.id);
      if (elem) {
        notAccepted.removeObject(elem);
        accepted.addObject(elem);
        attachPolicy($elem, helper);
      }
      ajax("/policy/accept", {
        type: 'put',
        data: {
          post_id: post.get('id')
        }
      }).catch(popupAjaxError);
      return false;
    });

    const $revokeButton = $policy.find('.btn.revoke');
    $revokeButton.on('click', function() {
      let elem = accepted.findBy('id', currentUser.id);
      if (elem) {
        accepted.removeObject(elem);
        notAccepted.addObject(elem);
        attachPolicy($elem, helper);
      }
      ajax("/policy/unaccept", {
        type: 'put',
        data: {
          post_id: post.get('id')
        }
      }).catch(popupAjaxError);
      return false;
    });
  }

  api.decorateCooked(attachPolicy, { onlyStream: true });
  api.registerCustomPostMessageCallback("policy_change", policyChanged);
}

export default {
  name: "extend-for-policy",

  initialize() {
    withPluginApi('0.8.7', initializePolicy);
  }
};
