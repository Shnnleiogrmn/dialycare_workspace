'use strict';
// Read-only service audit using the already installed and signed-in Firebase CLI.
// No access tokens, refresh tokens, account records, or secrets are printed.
const path = require('node:path');
const cli = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
const {selectAccount, setActiveAccount} = require(path.join(cli, 'auth'));
const {requireAuth} = require(path.join(cli, 'requireAuth'));
const {Client} = require(path.join(cli, 'apiv2'));
const project = 'dialycare-backend-3f0ed';
async function main() {
  const options = {project, projectId: project, nonInteractive: true};
  const account = selectAccount(undefined, __dirname);
  if (!account) throw new Error('Run firebase login first.');
  setActiveAccount(options, account);
  await requireAuth(options);
  console.log(JSON.stringify({project, cliAuthenticated: true}));
  const checks = [
    ['billing', 'https://cloudbilling.googleapis.com', 'v1', `/projects/${project}/billingInfo`, b => ({billingEnabled: b.billingEnabled})],
    ['functions', 'https://cloudfunctions.googleapis.com', 'v2', `/projects/${project}/locations/us-central1/functions`, b => ({functions: (b.functions || []).map(f => ({name: f.name, state: f.state, uri: f.serviceConfig?.uri}))})],
    ['firestore', 'https://firestore.googleapis.com', 'v1', `/projects/${project}/databases`, b => ({databases: (b.databases || []).map(d => ({name: d.name, locationId: d.locationId, type: d.type, createTime:d.createTime,deleteProtectionState:d.deleteProtectionState}))})],
    ['authentication', 'https://identitytoolkit.googleapis.com', 'admin/v2', `/projects/${project}/config`, b => ({emailPasswordEnabled: b.signIn?.email?.enabled, passwordRequired: b.signIn?.email?.passwordRequired})],
    ['services', 'https://serviceusage.googleapis.com', 'v1', `/projects/${project}/services?filter=state%3AENABLED&pageSize=200`, b => ({enabled: (b.services || []).map(s => s.config?.name).filter(n => /firestore|cloudfunctions|fcm|identitytoolkit|cloudbuild|artifactregistry|run.googleapis/.test(n))})],
  ];
  await Promise.all(checks.map(async ([service, urlPrefix, apiVersion, endpoint, summarize]) => {
    try {
      const result = await new Client({urlPrefix, apiVersion}).get(endpoint, {timeout: 20000, retries: 0});
      console.log(JSON.stringify({service, ...summarize(result.body)}));
    } catch (error) {
      console.log(JSON.stringify({service, error: error.message, status: error.status, details: error.context?.body?.error?.message,
        cause: error.original ? {message:error.original.message,code:error.original.code,cause:error.original.cause?.message} : undefined}));
    }
  }));
}
main().catch(e => {console.error(e.message); process.exitCode = 1;});
