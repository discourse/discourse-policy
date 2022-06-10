import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { click, fillIn } from "@ember/test-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

function assertOutput(assert, output) {
  assert.equal(query(".output").innerText, output);
}

discourseModule(
  "Discourse Policy | Component | policy-builder-form",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("onChange", {
      template: hbs`<span class="output"></span>{{policy-builder-form onChange=onChange}}`,

      beforeEach() {
        this.set("onChange", (key, value) => {
          query(".output").innerText = `${key}=${value}`;
        });
      },

      async test(assert) {
        const groupsChooser = selectKit(".group-chooser");
        await groupsChooser.expand();
        await groupsChooser.selectRowByValue("admins");
        assertOutput(assert, "groups=admins");

        await fillIn("input[name='version']", "1");
        assertOutput(assert, "version=1");

        await fillIn("input[name='renew']", "1");
        assertOutput(assert, "renew=1");

        await fillIn("input[name='renew-start']", "2022-06-07");
        assertOutput(assert, "renew-start=2022-06-07");

        const reminderChooser = selectKit(".combo-box");
        await reminderChooser.expand();
        await reminderChooser.selectRowByValue("weekly");
        assertOutput(assert, "reminder=weekly");

        await fillIn("input[name='accept']", "foo");
        assertOutput(assert, "accept=foo");

        await fillIn("input[name='revoke']", "bar");
        assertOutput(assert, "revoke=bar");

        await click("input[name='private']");
        assertOutput(assert, "private=true");
      },
    });
  }
);
