'use strict';
// Explicit live verification with disposable, fictional fixtures. Never scheduled.
// CLI IAM is used ONLY for fixture provisioning/cleanup. Flutter operations use
// real Firebase ID tokens and the deployed Security Rules.
const {connect}=require('./inspect-database-powershell.cjs');
const {randomBytes}=require('node:crypto');
const {spawnSync}=require('node:child_process');
const fs=require('node:fs'),path=require('node:path');
const deleteFreshFixtureAccount=require('./fixture-auth-cleanup.cjs');
const project='dialycare-backend-3f0ed';
const root=`projects/${project}/databases/(default)/documents`;
const url='https://firestore.googleapis.com/v1/'+root;
const encode=value=>value===null?{nullValue:null}:typeof value==='number'?{integerValue:String(value)}:typeof value==='boolean'?{booleanValue:value}:{stringValue:String(value)};
const document=(p,data)=>({name:root+'/'+p,fields:Object.fromEntries(Object.entries(data).map(([k,v])=>[k,encode(v)]))});
async function main(){
 if(process.argv[2]!=='--explicit-live-fixtures')throw Error('Use --explicit-live-fixtures for this manually initiated live test.');
 const request=await connect();
 // A quota failure here stops BEFORE any Auth identities or records are created.
 try{request(url+'/clinical/state');}catch(e){if(!e.message.includes('404'))throw e;}
 const config=fs.readFileSync(path.resolve(__dirname,'../dialycare_staff/lib/firebase_options.dart'),'utf8');
 const key=config.match(/apiKey:\s*'([^']+)'/)[1];
 const auth=(action,body)=>request('https://identitytoolkit.googleapis.com/v1/accounts:'+action+'?key='+key,'POST',body,'');
 const nonce=randomBytes(7).toString('hex');
 const counter=request(url+'/idCounters/center').fields;
 const fixture={patientId:'DC-DIAG-'+nonce,relativeId:'R-DIAG-'+nonce,
  patientPublicId:'DC-'+String(counter.nextPatientNumber.integerValue).padStart(6,'0'),
  relativePublicId:'R-'+String(counter.nextRelativeNumber.integerValue).padStart(6,'0')};
 // Confirm the randomly generated care-record paths are unoccupied before
 // allowing cleanup to own them. No existing care record is a test fixture.
 for(const p of ['patients/'+fixture.patientId,'relatives/'+fixture.relativeId]){
  let exists=true;try{request(url+'/'+p);}catch(e){if(e.message.includes('404'))exists=false;else throw e;}
  if(exists)throw Error('Fixture identifier collision; nothing changed.');
 }
 const accounts=[],passwords={};
 const original=new Map();
 for(const collection of ['patients','relatives','sessions']){
  const rows=request(url+':runQuery','POST',{structuredQuery:{from:[{collectionId:collection}],select:{fields:[{fieldPath:'__name__'}]}}});
  for(const row of Array.isArray(rows)?rows:[rows])if(row.document)original.set(row.document.name,row.document.updateTime);
 }
 try{
  for(const role of ['staff','helper','patient','relative']){
   const email=role==='patient'?fixture.patientPublicId.toLowerCase()+'@patient.dialycare.invalid':role==='relative'?fixture.relativePublicId.toLowerCase()+'@relative.dialycare.invalid':role+'-'+nonce+'@verification.dialycare.invalid';
   const password=randomBytes(12).toString('base64url');
   const account=auth('signUp',{email,password,returnSecureToken:true});
   accounts.push(account);passwords[role]={email,password};fixture[role]={idToken:account.idToken,localId:account.localId};
  }
  request(url+':commit','POST',{writes:[{update:document('users/'+fixture.staff.localId,{role:'staff',disabled:false,accountStatus:'active'}),currentDocument:{exists:false}}]});
  const runWorkflow=()=>{const result=spawnSync('cmd.exe',['/d','/c','flutter.bat test test/live_repository_verification_test.dart'],{
   cwd:path.resolve(__dirname,'../dialycare_staff'),encoding:'utf8',maxBuffer:2*1024*1024,
   env:{...process.env,DIALYCARE_LIVE_FIXTURE:JSON.stringify(fixture)},timeout:480000,
  });
  const output=(result.stdout||'')+'\n'+(result.stderr||'');
  // Never echo Auth responses or fixture passwords/tokens.
  console.log(output);
  if(result.status!==0)throw Error('Live repository verification failed.');};
  runWorkflow();
  // The first Flutter process exits while the session remains active. A new
  // process must reconstruct its timer from Firestore before completing it.
  fixture.phase='pause';runWorkflow();
  fixture.phase='resume';runWorkflow();
  fixture.phase='finish';
  runWorkflow();
  for(const role of ['patient','relative']){
   const login=auth('signInWithPassword',{...passwords[role],returnSecureToken:true});
   if(login.localId!==fixture[role].localId)throw Error('ID/password login returned an unexpected identity.');
   const user=request(url+'/users/'+login.localId,'GET',undefined,login.idToken);
   if(user.fields.role.stringValue!==role)throw Error('Login role mismatch.');
   fixture[role].idToken=login.idToken;
  }
  fixture.phase='relogin';
  runWorkflow();
  console.log('LIVE_ID_PASSWORD_LOGINS_VERIFIED for both roles; credentials were not saved.');
  for(const collection of ['patients','relatives','sessions']){
   const rows=request(url+':runQuery','POST',{structuredQuery:{from:[{collectionId:collection}],select:{fields:[{fieldPath:'__name__'}]}}});
   for(const row of Array.isArray(rows)?rows:[rows])if(row.document&&original.has(row.document.name)&&original.get(row.document.name)!==row.document.updateTime)throw Error('An existing care record changed during verification: '+row.document.name);
  }
  console.log('ORIGINAL_CARE_RECORD_UPDATE_TIMES_UNCHANGED');
  console.log(JSON.stringify({verifiedPatientId:fixture.patientPublicId,verifiedRelativeId:fixture.relativePublicId,idsRemainPermanentlyReserved:true}));
 }finally{
  // Remove every owned Auth identity even if Firestore cleanup is unavailable.
  for(const [index,account] of accounts.entries()){
   try{
    const role=['staff','helper','patient','relative'][index];
    deleteFreshFixtureAccount(auth,passwords[role],account.localId);
   }catch(e){console.error('Owned Auth fixture cleanup needs review: '+e.message);process.exitCode=1;}
  }
  const pid=fixture.patientId,rid=fixture.relativeId;
  const paths=['patients/'+pid,'patientProfiles/'+pid,'patientAccountProfiles/'+pid,'relatives/'+rid,'patientRelativeLinks/'+rid+'_'+pid,'sessions/S-'+pid,'notifications/N-'+pid,'accountBindings/patient_'+pid,'accountBindings/relative_'+rid];
  for(const account of accounts)paths.push('users/'+account.localId,'policyAcceptances/'+account.localId);
  let rows=[];
  try { rows=request(url+':runQuery','POST',{structuredQuery:{from:[{collectionId:'invitations'}],where:{fieldFilter:{field:{fieldPath:'recipientId'},op:'IN',value:{arrayValue:{values:[encode(pid),encode(rid)]}}}},select:{fields:[{fieldPath:'recipientId'}]}}}); } catch(e) { console.error('Invitation fixture cleanup lookup needs review: '+e.message); process.exitCode=1; }
  for(const row of Array.isArray(rows)?rows:[rows])if(row.document)paths.push(row.document.name.substring(root.length+1));
  const sessionIds=new Set();
  for(const collection of ['sessions','notifications','sessionEvents']){
   const owned=request(url+':runQuery','POST',{structuredQuery:{from:[{collectionId:collection}],where:{fieldFilter:{field:{fieldPath:'patientId'},op:'EQUAL',value:encode(pid)}},select:{fields:[{fieldPath:'patientId'}]}}});
   for(const row of Array.isArray(owned)?owned:[owned])if(row.document){
    const ownedPath=row.document.name.substring(root.length+1);paths.push(ownedPath);
    if(collection==='sessions')sessionIds.add(ownedPath.split('/')[1]);
   }
  }
  const writes=[...new Set(paths)].map(p=>({delete:root+'/'+p}));
  // Preserve current metadata. Touch only the revision so any concurrently
  // connected Staff client notices fixture cleanup, without restoring a stale snapshot.
  try {
   const current=request(url+'/clinical/state');
   const update=document('clinical/state',{revision:Date.now()*1000});
   for(const field of ['notificationEvents','notifications'])if(current.fields[field]){
    const values=current.fields[field].arrayValue?.values||[];
    update.fields[field]={arrayValue:{values:values.filter(value=>{
     const f=value.mapValue?.fields||{};
     return !sessionIds.has(f.sessionId?.stringValue)&&![...sessionIds].some(id=>f.id?.stringValue==='N-'+id);
    })}};
   }
   writes.push({update,updateMask:{fieldPaths:Object.keys(update.fields)},currentDocument:{updateTime:current.updateTime}});
  }catch(e){if(!e.message.includes('404')){console.error('Cleanup revision lookup needs review: '+e.message);process.exitCode=1;}}
  try{request(url+':commit','POST',{writes});console.log('Owned live care fixtures and mappings cleaned up; audit history retained.');}
  catch(e){console.error('FIXTURE CLEANUP NEEDS REVIEW: '+e.message);process.exitCode=1;}

 }
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
