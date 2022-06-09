import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { click } from "@ember/test-helpers";
import EmberObject from "@ember/object";
import pretender from "discourse/tests/helpers/create-pretender";

function fabricatePost(options = {}) {
  return EmberObject.create(Object.assign({ id: 1 }, options));
}

function fabricatePolicy(options = {}) {
  return EmberObject.create(
    Object.assign({ accept: "ok", revoke: "not ok" }, options)
  );
}

discourseModule("Discourse Policy | Component | post-policy", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("empty post", {
    template: hbs`{{post-policy post=post policy=policy}}`,

    async test(assert) {
      assert.notOk(exists(".policy-footer"));
    },
  });

  componentTest("post#policy_can_accept", {
    template: hbs`{{post-policy post=post policy=policy}}`,

    beforeEach() {
      this.set("post", fabricatePost({ policy_can_accept: true }));
      this.set("policy", fabricatePolicy());
    },

    async test(assert) {
      assert.ok(exists(".btn-accept-policy"));
      assert.equal(query(".btn-accept-policy").innerText, this.policy.accept);
    },
  });

  componentTest("post#policy_can_revoke", {
    template: hbs`{{post-policy post=post policy=policy}}`,

    beforeEach() {
      this.set("post", fabricatePost({ policy_can_revoke: true }));
      this.set("policy", fabricatePolicy());
    },

    async test(assert) {
      assert.ok(exists(".btn-revoke-policy"));
      assert.equal(query(".btn-revoke-policy").innerText, this.policy.revoke);
    },
  });

  componentTest("post#policy_accepted_by_count", {
    template: hbs`{{post-policy post=post policy=policy}}`,

    beforeEach() {
      this.set("post", fabricatePost({ policy_accepted_by_count: 10 }));
      this.set("policy", fabricatePolicy());
    },

    async test(assert) {
      assert.equal(
        query(".toggle-accepted .user-count").innerText,
        this.post.policy_accepted_by_count
      );
    },
  });
  componentTest("post#policy_not_accepted_by_count", {
    template: hbs`{{post-policy post=post policy=policy}}`,

    beforeEach() {
      this.set("post", fabricatePost({ policy_not_accepted_by_count: 10 }));
      this.set("policy", fabricatePolicy());
    },

    async test(assert) {
      assert.equal(
        query(".toggle-not-accepted .user-count").innerText,
        this.post.policy_not_accepted_by_count
      );
    },
  });

  componentTest("toggle state", {
    template: hbs`{{post-policy post=post policy=policy}}`,

    beforeEach() {
      const acceptedByUsers = [
        { id: 1, username: "jeanne", avatar_template: "/images/avatar.png" },
      ];

      const notAcceptedByUsers = [
        { id: 2, username: "bob", avatar_template: "/images/avatar.png" },
        { id: 3, username: "alex", avatar_template: "/images/avatar.png" },
      ];

      this.set(
        "post",
        fabricatePost({
          policy_accepted_by: acceptedByUsers,
          policy_accepted_by_count: 1,
          policy_not_accepted_by: notAcceptedByUsers,
          policy_not_accepted_by_count: 3,
        })
      );
      this.set("policy", fabricatePolicy());
    },

    async test(assert) {
      assert.equal(queryAll(".users.accepted .avatar").length, 1);
      assert.equal(
        query(".user-lists .toggle-accepted .user-count").innerText,
        1
      );
      assert.notOk(exists(".users.not-accepted"));

      await click(".toggle-not-accepted");

      assert.notOk(exists(".users.accepted"));
      assert.equal(queryAll(".users.not-accepted .avatar").length, 2);
      assert.equal(
        query(".user-lists .toggle-not-accepted .user-count").innerText,
        3
      );
      assert.equal(query(".load-more-users").innerText.trim(), "+ 1");

      await click(".toggle-accepted");

      assert.ok(exists(".users.accepted"));
      assert.notOk(exists(".users.not-accepted"));
    },
  });

  componentTest("accept policy", {
    template: hbs`{{post-policy post=post policy=policy currentUser=currentUser}}`,

    beforeEach() {
      this.set("currentUser", {
        id: 1,
        username: "bob",
        avatar_template: "/images/avatar.png",
      });
      this.set(
        "post",
        fabricatePost({
          policy_can_accept: true,
          policy_not_accepted_by: [this.currentUser],
          policy_not_accepted_by_count: 1,
        })
      );
      this.set("policy", fabricatePolicy());
    },

    async test(assert) {
      pretender.put("/policy/accept", () => {
        this.post.set("policy_accepted_by", this.currentUser);
        this.post.set("policy_accepted_by_count", 1);
        return [200, { "Content-Type": "application/json" }, {}];
      });

      await click(".btn-accept-policy");

      assert.ok(exists(".btn-revoke-policy"));
      assert.equal(
        query(".user-lists .toggle-accepted .user-count").innerText.trim(),
        1
      );
    },
  });

  componentTest("revoke policy", {
    template: hbs`{{post-policy post=post policy=policy currentUser=currentUser}}`,

    beforeEach() {
      this.set("currentUser", {
        id: 1,
        username: "bob",
        avatar_template: "/images/avatar.png",
      });
      this.set(
        "post",
        fabricatePost({
          policy_can_revoke: true,
          policy_accepted_by: [this.currentUser],
          policy_accepted_by_count: 1,
        })
      );
      this.set("policy", fabricatePolicy());
    },

    async test(assert) {
      pretender.put("/policy/unaccept", () => {
        this.post.set("policy_not_accepted_by", this.currentUser);
        this.post.set("policy_not_accepted_by_count", 1);
        return [200, { "Content-Type": "application/json" }, {}];
      });

      await click(".btn-revoke-policy");

      assert.ok(exists(".btn-accept-policy"));
      assert.equal(
        query(".user-lists .toggle-not-accepted .user-count").innerText.trim(),
        1
      );
    },
  });
});
