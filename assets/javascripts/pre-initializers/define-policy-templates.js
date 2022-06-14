export default {
  name: "define-policy-templates",
  after: "inject-discourse-objects",

  initialize() {
    const template = "javascripts/components/post-policy";
    // eslint-disable-next-line no-undef
    define(template, () => Ember.TEMPLATES[template]);
  },
};
