export const POLICY_SETTINGS = [
  { name: "group", visible: true },
  { name: "version", visible: true, optional: true },
  { name: "renew", visible: true, optional: true },
  { name: "renew-start", visible: true, optional: true },
  { name: "reminder", optional: true },
  { name: "accept", optional: true },
  { name: "revoke", optional: true },
];

function addPolicySettings(options) {
  POLICY_SETTINGS.pushObjects(options);
}

export { addPolicySettings };
