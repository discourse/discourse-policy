export default {
  name: "define-policy-templates",
  after: "inject-discourse-objects",

  initialize() {
    const template = "javascripts/components/post-policy";
    define(template, () => Ember.TEMPLATES[template]);
  },
};
