'use strict';
// Local-only full capstone check; the existing Auth harness validates all hosts.
const {spawnSync}=require('node:child_process');
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8089'||process.env.FIREBASE_AUTH_EMULATOR_HOST!=='127.0.0.1:9099'||process.env.GCLOUD_PROJECT!=='demo-dialycare-spark')throw Error('Only the explicit local demo emulators are allowed.');
for(const args of [['run-account-auth-emulator.cjs'],['--test','--test-concurrency=1','rules.test.cjs','activation.rules.test.cjs']]){
 const result=spawnSync(process.execPath,args,{cwd:__dirname,stdio:'inherit',env:process.env});
 if(result.status!==0){process.exitCode=result.status??1;break;}
}
