import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class PreferencesPolicyRoute extends RestrictedUserRoute {

  showFooter = true;

  setupController(controller, user) {
    controller.set("model", user);
  }
}
