import Controller from "@ember/controller";
import { action } from "@ember/object";
import { popupAjaxError }  from "discourse/lib/ajax-error";

const POLICY_ATTRS = [
    "policy_emails_enabled",
];

export default class PreferencesPolicyController extends Controller {
    @action
    save() {
        console.log('controller save');
        console.log(this.model);
        this.set("saved", false);
        return this.model
            .save(POLICY_ATTRS)
            .then (() => {
                this.set("saved", true);
            })
            .catch(popupAjaxError);
    }
}
