import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import postFixtures from "discourse/tests/fixtures/post";

acceptance("Discourse Policy - post", function (needs) {
  needs.user();

  needs.settings({
    policy_enabled: true,
  });

  needs.pretender((server, helper) => {
    const topic = cloneJSON(topicFixtures["/t/130.json"]);
    const post = cloneJSON(postFixtures["/posts/18"]);

    post.topic_id = topic.id;
    post.policy_can_accept = true;
    post.cooked = `<div class=\"policy\" data-group=\"everyone\" data-version=\"1\">\n<p>test</p>\n</div>`;

    topic.post_stream = {
      posts: [post],
      stream: [post.id],
    };

    server.get("/t/130.json", () => helper.response(topic));
    server.put("/policy/accept", () => helper.response(200, {}));
    server.put("/policy/unaccept", () => helper.response(200, {}));
  });

  test("edit policy - staff", async function (assert) {
    await visit("/t/-/130");
    await click(".edit-policy-settings-btn");

    assert.ok(exists(".policy-builder"));
  });

  test("edit policy - not staff", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false });
    await visit("/t/-/130");

    assert.notOk(exists(".edit-policy-settings-btn"));
  });

  test("edit policy - not staff, post owner", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, id: 1 });
    await visit("/t/-/130");

    assert.ok(exists(".edit-policy-settings-btn"));
  });

  test("accept a policy", async function (assert) {
    await visit("/t/-/130");
    await click(".btn-accept-policy");

    assert.ok(exists(".btn-revoke-policy"));
  });

  test("revoke a policy", async function (assert) {
    await visit("/t/-/130");
    await click(".btn-accept-policy");
    await click(".btn-revoke-policy");

    assert.ok(exists(".btn-accept-policy"));
  });
});
