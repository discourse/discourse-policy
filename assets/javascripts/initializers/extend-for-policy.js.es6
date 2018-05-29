import {withPluginApi} from 'discourse/lib/plugin-api';
import {renderAvatar} from 'discourse/helpers/user-avatar';
import {ajax} from 'discourse/lib/ajax';
import {popupAjaxError} from 'discourse/lib/ajax-error';
import {escapeExpression} from 'discourse/lib/utilities';

let currentUser;

function initializePolicy(api) {
  currentUser = api.getCurrentUser();

  function loadPolicyUsers(users) {
    if (!users) {
      return [];
    }

    return users.map(u => {
      return renderAvatar(u, {imageSize: 'tiny'});
    });
  }

  function render($policy, post) {
    $policy.find('.policy-header, .policy-footer').remove();

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

    const notAcceptedHtml = $(
      "<div class='users not-accepted'><i class='fa fa-user-times'></i>" +
        loadPolicyUsers(notAccepted).join('') +
        '</div>',
    );
    const acceptedHtml = $(
      "<div class='users accepted'>" +
        loadPolicyUsers(accepted).join('') +
        '</div>',
    );

    let countNotAcceptedHtml = '';
    if (notAccepted.length > 0) {
      let title = escapeExpression(
        I18n.t('discourse_policy.not_accepted_tooltip'),
      );
      countNotAcceptedHtml = `<a class='toggle-not-accepted' title='${title}'><i class='toggle-not-accepted fa fa-user-times'></i>${
        notAccepted.length
      }</a>`;
    }

    let countAcceptedHtml = '';
    if (accepted.length > 0) {
      let title = escapeExpression(I18n.t('discourse_policy.accepted_tooltip'));
      countAcceptedHtml = `<a class='toggle-accepted' title='${title}'><i class='toggle-accepted fa fa-user'></i>${
        accepted.length
      }</a>`;
    }

    const $header = $('<div class="policy-header"></div>');
    $header.append(countNotAcceptedHtml);
    $header.append(countAcceptedHtml);

    const revokeText = escapeExpression(
      $policy.data('revoke') || I18n.t('discourse_policy.revoke_policy'),
    );
    const acceptText = escapeExpression(
      $policy.data('accept') || I18n.t('discourse_policy.accept_policy'),
    );
    const $footer = $('<div class="policy-footer"></div>');
    $footer
      .append(acceptedHtml)
      .append(notAcceptedHtml)
      .append(
        `<button class='btn btn-danger revoke btn-revoke-policy'>${revokeText}</button>`,
      )
      .append(
        `<button class='btn btn-primary accept btn-accept-policy'>${acceptText}</button>`,
      );

    $policy.prepend($header).append($footer);

    let currentAccepted, currentNotAccepted;

    if (currentUser) {
      currentAccepted = accepted.any(u => u.id === currentUser.id);
      currentNotAccepted = notAccepted.any(u => u.id === currentUser.id);
    }

    $policy.find('.btn.accept, .btn.revoke').hide();

    if ($policy.attr('data-show-unaccepted')) {
      $policy.find('.users.accepted').hide();
    } else {
      $policy.find('.users.not-accepted').hide();
    }

    if (currentAccepted) {
      $policy.find('.btn.revoke').show();
    }

    if (currentNotAccepted) {
      $policy.find('.btn.accept').show();
    }
  }

  function attachPolicy($elem, helper) {
    const $policy = $elem.find('.policy');

    if ($policy.length === 0) {
      return;
    }

    render($policy, helper.getModel());
  }

  function revokePolicy($policy, post) {
    let notAccepted = post.get('policy_not_accepted_by');
    let accepted = post.get('policy_accepted_by');

    let elem = accepted.findBy('id', currentUser.id);

    if (elem) {
      accepted.removeObject(elem);
      notAccepted.addObject(elem);
      render($policy, post);
    }
    ajax('/policy/unaccept', {
      type: 'put',
      data: {
        post_id: post.get('id'),
      },
    }).catch(popupAjaxError);
    return false;
  }

  function acceptPolicy($policy, post) {
    let notAccepted = post.get('policy_not_accepted_by');
    let accepted = post.get('policy_accepted_by');

    let elem = notAccepted.findBy('id', currentUser.id);

    if (elem) {
      notAccepted.removeObject(elem);
      accepted.addObject(elem);
      render($policy, post);
    }
    ajax('/policy/accept', {
      type: 'put',
      data: {
        post_id: post.get('id'),
      },
    }).catch(popupAjaxError);
    return false;
  }

  function policyChanged(topicsController, message) {
    const stream = topicsController.get('model.postStream');
    const post = stream.findLoadedPost(message.id);

    const $policy = $(`article[data-post-id=${message.id}] .policy`);

    if (post && $policy.length > 0) {
      ajax(`/posts/${message.id}.json`).then(data => {
        post.set('policy_accepted_by', data.policy_accepted_by || []);
        post.set('policy_not_accepted_by', data.policy_not_accepted_by || []);
        render($policy, post);
      });
    }
  }

  api.decorateCooked(attachPolicy, {onlyStream: true});
  api.registerCustomPostMessageCallback('policy_change', policyChanged);

  api.modifyClass('component:discourse-topic', {
    click: function(arg) {
      const $target = $(arg.target);

      const findPost = () => {
        const postId = $target.closest('article').attr('data-post-id');
        return this.get('postStream').findLoadedPost(postId);
      };

      if ($target.hasClass('btn-accept-policy')) {
        const $policy = $target.closest('.policy');
        const post = findPost();

        acceptPolicy($policy, post);

        return false;
      }

      if ($target.hasClass('btn-revoke-policy')) {
        const $policy = $target.closest('.policy');
        const post = findPost();

        revokePolicy($policy, post);

        return false;
      }

      if ($target.hasClass('toggle-accepted')) {
        const $policy = $target.closest('.policy');
        const post = findPost();

        $policy.removeAttr('data-show-unaccepted');

        render($policy, post);
      }

      if ($target.hasClass('toggle-not-accepted')) {
        const $policy = $target.closest('.policy');
        const post = findPost();

        $policy.attr('data-show-unaccepted', 'true');

        render($policy, post);
      }

      this._super(arg);
    },
  });
}

export default {
  name: 'extend-for-policy',

  initialize() {
    withPluginApi('0.8.7', initializePolicy);
  },
};
