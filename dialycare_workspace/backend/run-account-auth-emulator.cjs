'use strict';
// Official local Auth + Firestore emulators only. No production credentials/data.
const {spawnSync} = require('node:child_process');
const {createRequire} = require('node:module');
const {randomBytes} = require('node:crypto');
const path = require('node:path');
const assert = require('node:assert/strict');
const project = 'demo-dialycare-spark';
async function main() {
  if (process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9099' ||
      process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8089' ||
      process.env.GCLOUD_PROJECT !== project) throw Error('Only the explicit local demo emulators are allowed.');
  const devRequire = createRequire(path.resolve(__dirname, 'functions/package.json'));
  const {initializeApp} = devRequire('firebase-admin/app');
  const {getAuth} = devRequire('firebase-admin/auth');
  const app = initializeApp({projectId:project});
  const auth = getAuth(app);
  const base = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';
  const tokens = {};
  async function api(action, body) {
    const response = await fetch(`${base}/${action}?key=emulator-only-public-key`, {
      method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(body),
    });
    return {status:response.status, data:await response.json()};
  }
  const password = randomBytes(24).toString('base64url');
  await auth.createUser({uid:'staff',email:'staff@example.com',password,emailVerified:true});
  const login = await api('accounts:signInWithPassword',{email:'staff@example.com',password,returnSecureToken:true});
  assert.equal(login.status,200);
  tokens.staff=login.data.idToken;
  const bad=await api('accounts:signInWithPassword',{email:'staff@example.com',password:'incorrect-test-password',returnSecureToken:true});
  assert.equal(bad.status,400);
  console.log('LOCAL STAFF AUTH VERIFIED. The Dart repository flow now creates and tests ID/PIN Mobile accounts without email verification or delivery.');
  const result = spawnSync('cmd.exe', ['/d','/c','flutter.bat test --timeout=6m --concurrency=1 test/spark_repository_flow_test.dart test/id_field_repository_test.dart'], {
    cwd:path.resolve(__dirname,'../dialycare_staff'), stdio:'inherit',
    env:{...process.env,DIALYCARE_TEST_AUTH_TOKENS:JSON.stringify(tokens)},
  });
  process.exitCode = result.status ?? 1;
  await app.delete();
}
main().catch(e => {console.error(e.message);process.exitCode=1;});
