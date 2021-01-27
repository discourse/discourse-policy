import { bind } from "discourse-common/utils/decorators";
import showModal from "discourse/lib/show-modal";
import getURL from "discourse-common/lib/get-url";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Component from "@ember/component";
import { action, computed } from "@ember/object";
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

  acceptedUsers: computed("post.policy_accepted_by.[]", function () {
    return this.post.policy_accepted_by || [];
  }),

  notAcceptedUsers: computed("post.policy_not_accepted_by.[]", function () {
    return this.post.policy_not_accepted_by || [];
  }),

  canManagePolicy: computed(
    "currentUser.{id,staff}",
    "post.user_id",
    function () {
      return (
        this.get("currentUser.staff") ||
        this.get("currentUser.id") === this.post.user_id
      );
    }
  ),

  currentlyAcceptedUser: computed(
    "currentUser.id",
    "acceptedUsers.[]",
    function () {
      return (
        this.currentUser && this.acceptedUsers.findBy("id", this.currentUser.id)
      );
    }
  ),

  notCurrentlyAcceptedUser: computed(
    "currentUser.id",
    "notAcceptedUsers.[]",
    function () {
      return (
        this.currentUser &&
        this.notAcceptedUsers.findBy("id", this.currentUser.id)
      );
    }
  ),

  @action
  revokePolicy(post) {
    this.post.policy_not_accepted_by.pushObject(this.currentlyAcceptedUser);
    this.post.set(
      "policy_accepted_by",
      this.post.policy_accepted_by.rejectBy("id", this.currentlyAcceptedUser.id)
    );

    this._updatePolicy("unaccept", post.id);

    return false;
  },

  @action
  editPolicy(post) {
    showModal("policy-builder").setProperties({
      insertMode: false,
      post,
      form: this.form,
    });
  },

  @action
  acceptPolicy(post) {
    this.post.policy_accepted_by.pushObject(this.notCurrentlyAcceptedUser);
    this.post.set(
      "policy_not_accepted_by",
      this.post.policy_not_accepted_by.rejectBy(
        "id",
        this.notCurrentlyAcceptedUser.id
      )
    );

    this._updatePolicy("accept", post.id);

    return false;
  },

  @action
  toggleShowUsers() {
    this.toggleProperty("showNotAccepted");
  },

  @bind
  policyChanged(data) {
    const stream = data.controller.get("model.postStream");
    const post = stream.findLoadedPost(data.message.id);

    if (post) {
      const endpoint = getURL(`/posts/${post.id}.json`);
      ajax(endpoint).then((result) => {
        this.post.set("policy_accepted_by", result.policy_accepted_by || []);
        this.post.set(
          "policy_not_accepted_by",
          result.policy_not_accepted_by || []
        );
      });
    }
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
});
