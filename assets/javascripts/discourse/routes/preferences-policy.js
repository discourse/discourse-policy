import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class PreferencesPolicyRoute extends RestrictedUserRoute {

  showFooter = true;

  setupController(controller, user) {
    console.log('does this fire?');
    console.log(user);
    controller.set("model", user);
  }
}
