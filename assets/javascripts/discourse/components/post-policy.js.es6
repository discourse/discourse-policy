import Component from "@ember/component";
import { action } from "@ember/object";
import getURL from "discourse-common/lib/get-url";
import discourseComputed, { bind } from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";
import layout from "javascripts/components/post-policy";

export default class PostPolicy extends Component {
  layout = layout;
  tagName = "";
  post = null;
  options = null;
  showNotAccepted = false;
  isLoading = false;
  policy = null;

  didInsertElement() {
    this._super(...arguments);

    this.post?.setProperties({
      policy_accepted_by: this.post?.policy_accepted_by || [],
      policy_not_accepted_by: this.post?.policy_not_accepted_by || [],
    });

    this.appEvents.on("policy:changed", this, "policyChanged");
  }

  willDestroyElement() {
    this._super(...arguments);

    this.appEvents.off("policy:changed", this, "policyChanged");
  }

  @bind
  policyChanged(data) {
    if (data.message.id !== this.post.id) {
      return;
    }

    const stream = data.controller.get("model.postStream");
    const post = stream.findLoadedPost(data.message.id);

    if (post) {
      const endpoint = getURL(`/posts/${post.id}.json`);
      ajax(endpoint).then((result) => {
        this.post.setProperties({
          policy_can_accept: result.policy_can_accept,
          policy_can_revoke: result.policy_can_revoke,
          policy_accepted: result.policy_accepted,
          policy_revoked: result.policy_revoked,
          policy_not_accepted_by: result.policy_not_accepted_by || [],
          policy_not_accepted_by_count: result.policy_not_accepted_by_count,
          policy_accepted_by: result.policy_accepted_by || [],
          policy_accepted_by_count: result.policy_accepted_by_count,
        });
      });
    }
  }

  @discourseComputed("post.policy_accepted", "post.policy_revoked")
  acceptButtonClasses(accepted, revoked) {
    let classes = "accept btn-accept-policy";
    if (!accepted || revoked) {
      classes += " btn-primary";
    }
    return classes;
  }

  @discourseComputed("post.policy_accepted", "post.policy_revoked")
  revokeButtonClasses(accepted, revoked) {
    let classes = "revoke btn-revoke-policy";
    if (!revoked || accepted) {
      classes += " btn-danger";
    }
    return classes;
  }

  @discourseComputed(
    "post.policy_accepted_by_count",
    "post.policy_accepted_by.[]"
  )
  remainingAcceptedUsers(count, loaded) {
    return count - loaded.length;
  }

  @discourseComputed("post.policy_accepted_by.[]")
  acceptedUsers() {
    return this.post.policy_accepted_by || [];
  }

  @discourseComputed(
    "post.policy_not_accepted_by_count",
    "post.policy_not_accepted_by.[]"
  )
  remainingNotAcceptedUsers(count, loaded) {
    return count - loaded.length;
  }

  @discourseComputed("post.policy_not_accepted_by.[]")
  notAcceptedUsers() {
    return this.post.policy_not_accepted_by || [];
  }

  @discourseComputed("currentUser.{id,staff}", "post.user_id")
  canManagePolicy() {
    return (
      this.currentUser &&
      (this.currentUser.staff || this.currentUser.id === this.post.user_id)
    );
  }

  @action
  revokePolicy() {
    this.post.policy_not_accepted_by.pushObject(this.currentUser);
    this.post.set(
      "policy_not_accepted_by_count",
      this.post.policy_not_accepted_by_count + 1
    );

    const obj = this.post.policy_accepted_by.findBy("id", this.currentUser.id);
    if (obj) {
      this.post.policy_accepted_by.removeObject(obj);
      this.post.set(
        "policy_accepted_by_count",
        this.post.policy_accepted_by_count - 1
      );
    }

    if (this.post.policy_can_accept !== this.post.policy_can_revoke) {
      this.post.setProperties({
        policy_can_accept: true,
        policy_can_revoke: false,
        policy_accepted: false,
        policy_revoked: true,
      });
    }

    this._updatePolicy("unaccept", this.post.id);
  }

  @action
  acceptPolicy() {
    this.post.policy_accepted_by.pushObject(this.currentUser);
    this.post.set(
      "policy_accepted_by_count",
      this.post.policy_accepted_by_count + 1
    );

    const obj = this.post.policy_not_accepted_by.findBy(
      "id",
      this.currentUser.id
    );

    if (obj) {
      this.post.policy_not_accepted_by.removeObject(obj);
      this.post.set(
        "policy_not_accepted_by_count",
        this.post.policy_not_accepted_by_count - 1
      );
    }

    if (this.post.policy_can_accept !== this.post.policy_can_revoke) {
      this.post.setProperties({
        policy_can_accept: false,
        policy_can_revoke: true,
        policy_accepted: true,
        policy_revoked: false,
      });
    }

    this._updatePolicy("accept", this.post.id);
  }

  @action
  loadRemainingAcceptedUsers() {
    ajax(getURL(`/policy/accepted`), {
      data: {
        post_id: this.post.id,
        offset: this.post.policy_accepted_by.length,
      },
    })
      .then((result) => {
        result.users.forEach((user) => {
          this.post.policy_accepted_by.pushObject(user);
        });
      })
      .catch(popupAjaxError);
  }

  @action
  loadRemainingNotAcceptedUsers() {
    ajax(getURL(`/policy/accepted`), {
      data: {
        post_id: this.post.id,
        offset: this.post.policy_not_accepted_by.length,
      },
    })
      .then((result) => {
        result.users.forEach((user) => {
          this.post.policy_not_accepted_by.pushObject(user);
        });
      })
      .catch(popupAjaxError);
  }

  @action
  editPolicy() {
    showModal("policy-builder").setProperties({
      insertMode: false,
      post: this.post,
      policy: this.policy,
    });
  }

  @action
  toggleShowUsers() {
    this.toggleProperty("showNotAccepted");
  }

  _updatePolicy(policyAction, id) {
    this.set("isLoading", true);

    return ajax(getURL(`/policy/${policyAction}`), {
      type: "put",
      data: { post_id: id },
    })
      .catch(popupAjaxError)
      .finally(() => this.set("isLoading", false));
  }
}
