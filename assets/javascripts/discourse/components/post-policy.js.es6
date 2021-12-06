import Component from "@ember/component";
import { action } from "@ember/object";
import getURL from "discourse-common/lib/get-url";
import discourseComputed, { bind } from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";
import layout from "javascripts/components/post-policy";

export default Component.extend({
  layout,

  tagName: "",
  post: null,
  options: null,
  showNotAccepted: false,
  isLoading: false,
  form: null,

  init() {
    this._super(...arguments);

    this.post.set("policy_accepted_by", this.post.policy_accepted_by || []);
    this.post.set(
      "policy_not_accepted_by",
      this.post.policy_not_accepted_by || []
    );
  },

  didInsertElement() {
    this._super(...arguments);

    this.appEvents.on("policy:changed", this, "policyChanged");
  },

  willDestroyElement() {
    this._super(...arguments);

    this.appEvents.off("policy:changed", this, "policyChanged");
  },

  @bind
  policyChanged(data) {
    const stream = data.controller.get("model.postStream");
    const post = stream.findLoadedPost(data.message.id);

    if (post) {
      const endpoint = getURL(`/posts/${post.id}.json`);
      ajax(endpoint).then((result) => {
        this.post.setProperties({
          policy_not_accepted_by: result.policy_not_accepted_by || [],
          policy_not_accepted_by_count: result.policy_not_accepted_by_count,
          policy_accepted_by: result.policy_accepted_by || [],
          policy_accepted_by_count: result.policy_accepted_by_count,
        });
      });
    }
  },

  @discourseComputed(
    "post.policy_accepted_by_count",
    "post.policy_accepted_by.[]"
  )
  remainingAcceptedUsers(count, loaded) {
    return count - loaded.length;
  },

  @discourseComputed("post.policy_accepted_by.[]")
  acceptedUsers() {
    return this.post.policy_accepted_by || [];
  },

  @discourseComputed(
    "post.policy_not_accepted_by_count",
    "post.policy_not_accepted_by.[]"
  )
  remainingNotAcceptedUsers(count, loaded) {
    return count - loaded.length;
  },

  @discourseComputed("post.policy_not_accepted_by.[]")
  notAcceptedUsers() {
    return this.post.policy_not_accepted_by || [];
  },

  @discourseComputed("currentUser.{id,staff}", "post.user_id")
  canManagePolicy() {
    return (
      this.currentUser &&
      (this.currentUser.staff || this.currentUser.id === this.post.user_id)
    );
  },

  _updatePolicy(policyAction, id) {
    this.set("isLoading", true);

    return ajax(getURL(`/policy/${policyAction}`), {
      type: "put",
      data: { post_id: id },
    })
      .catch(popupAjaxError)
      .finally(() => this.set("isLoading", false));
  },

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

    this.post.set("policy_can_accept", true);
    this.post.set("policy_can_revoke", false);

    this._updatePolicy("unaccept", this.post.id);
  },

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

    this.post.set("policy_can_accept", false);
    this.post.set("policy_can_revoke", true);

    this._updatePolicy("accept", this.post.id);
  },

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
  },

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
  },

  @action
  editPolicy() {
    showModal("policy-builder").setProperties({
      insertMode: false,
      post: this.post,
      form: this.form,
    });
  },

  @action
  toggleShowUsers() {
    this.toggleProperty("showNotAccepted");
  },
});
