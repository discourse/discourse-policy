import { query } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { click, fillIn, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Discourse Policy | Integration | Component | policy-builder-form",
  function (hooks) {
    setupRenderingTest(hooks);

    test("onChange", async function (assert) {
      this.set("onChange", (key, value) => {
        query(".output").innerText = `${key}=${value}`;
      });

      await render(hbs`
      <span class="output"></span>
      <PolicyBuilderForm @onChange={{this.onChange}} />
    `);

      const groupsChooser = selectKit(".group-chooser");
      await groupsChooser.expand();
      await groupsChooser.selectRowByValue("admins");
      assert.dom(".output").hasText("groups=admins");

      await fillIn("input[name='version']", "1");
      assert.dom(".output").hasText("version=1");

      await fillIn("input[name='renew']", "1");
      assert.dom(".output").hasText("renew=1");

      await fillIn("input[name='renew-start']", "2022-06-07");
      assert.dom(".output").hasText("renew-start=2022-06-07");

      const reminderChooser = selectKit(".combo-box");
      await reminderChooser.expand();
      await reminderChooser.selectRowByValue("weekly");
      assert.dom(".output").hasText("reminder=weekly");

      await fillIn("input[name='accept']", "foo");
      assert.dom(".output").hasText("accept=foo");

      await fillIn("input[name='revoke']", "bar");
      assert.dom(".output").hasText("revoke=bar");

      await click("input[name='private']");
      assert.dom(".output").hasText("private=true");
    });
  }
);
