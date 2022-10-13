import Controller from "@ember/controller";
import { action } from "@ember/object";
import { popupAjaxError }  from "discourse/lib/ajax-error";

const POLICY_ATTRS = [
    "send_email_notifications",
];

export default class PreferencesPolicyController extends Controller {
    @action
    save() {
        this.set("saved", false);
        return this.model
            .save(POLICY_ATTRS)
            .then (() => {
                this.set("saved", true);
            })
            .catch(popupAjaxError);
    }
}
