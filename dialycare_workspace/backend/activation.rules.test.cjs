'use strict';
const {test,before,after}=require('node:test'),assert=require('node:assert/strict');
const {randomInt,createHash}=require('node:crypto'),{readFileSync}=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,getDocs,collection,updateDoc,writeBatch,serverTimestamp,Timestamp}=require('firebase/firestore');
let env,count=0;
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-dialycare-activation',firestore:{host:'127.0.0.1',port:8089,rules:readFileSync('firestore.spark.rules','utf8')}});
 await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'users/staff'),{role:'staff',disabled:false,accountStatus:'active'}));
});
after(async()=>{await env?.cleanup();});
const staff=()=>env.authenticatedContext('staff').firestore();
const user=(uid,email='unlinked@activation.dialycare.invalid')=>env.authenticatedContext(uid,{email,email_verified:false}).firestore();
const alias=f=>`${f.rid.toLowerCase()}@${f.role}.dialycare.invalid`;
const owner=(uid,f)=>user(uid,alias(f));
const hash=(role,id,pin)=>createHash('sha256').update(`dialycare-pin-v1\n${role}\n${id.toLowerCase()}\n${pin}`).digest('hex');
async function fixture(role='patient'){
 const pid='DC-ACT-'+(++count),rid=role==='patient'?pid:'REL-ACT-'+count;
 await env.withSecurityRulesDisabled(async c=>{
  const db=c.firestore();await setDoc(doc(db,'patients',pid),{id:pid,name:'Anna Marie'});await setDoc(doc(db,'patientProfiles',pid),{id:pid,name:'Anna Marie'});
  if(role==='relative'){await setDoc(doc(db,'relatives',rid),{id:rid,name:'Robert'});await setDoc(doc(db,'patientRelativeLinks',rid+'_'+pid),{relativeId:rid,patientId:pid,active:true});}
 });
 const f={pid,rid,role,key:role+'_'+rid};await issue(f);return f;
}
async function issue(f){
 f.pin=String(randomInt(100000,1000000));f.code=hash(f.role,f.rid,f.pin);
 const db=staff(),batch=writeBatch(db);
 batch.set(doc(db,'invitations',f.code),{mode:'temporaryPinV1',role:f.role,patientId:f.pid,recipientId:f.rid,displayName:f.role==='patient'?'Anna Marie':'Robert',expiresAt:Timestamp.fromMillis(Date.now()+3600000),issuedBy:'staff',usedBy:null,usedAt:null,revoked:false});
 batch.set(doc(db,'accountBindings',f.key),{role:f.role,patientId:f.pid,recipientId:f.rid,uid:null,activationId:f.code,accountStatus:'activationPending',activatedAt:null});
 await assertSucceeds(batch.commit());
}
function claim(f,uid,db=owner(uid,f),overrides={},acceptance={}){
 const batch=writeBatch(db),mapping={role:f.role,patientId:f.pid,recipientId:f.rid,activationId:f.code,disabled:false,accountStatus:'active',activatedAt:serverTimestamp(),...overrides};
 batch.set(doc(db,'policyAcceptances',uid),{uid,role:f.role,termsVersion:'capstone-2026-10-19-v1',privacyNoticeVersion:'capstone-2026-10-19-v1',termsAcceptedAt:serverTimestamp(),privacyAcknowledgedAt:serverTimestamp(),...acceptance});
 batch.set(doc(db,'users',uid),mapping);const binding={...mapping,uid};delete binding.disabled;
 batch.set(doc(db,'accountBindings',f.key),binding);batch.update(doc(db,'invitations',f.code),{usedBy:uid,usedAt:serverTimestamp()});return batch.commit();
}
test('both ID roles activate atomically without a real email or verified inbox',async()=>{
 for(const role of ['patient','relative']){const f=await fixture(role),uid='valid-'+role;
  await assertSucceeds(getDoc(doc(user('preview-'+role),'invitations',hash(role,f.rid,f.pin))));
  await assertFails(getDoc(doc(user('preview-'+role),'patientProfiles',f.pid)));
  await assertSucceeds(claim(f,uid));await assertSucceeds(getDoc(doc(owner(uid,f),'patientProfiles',f.pid)));
 }
});
test('ID alone, a wrong PIN, anonymous access and invitation listing give no activation identity',async()=>{
 const f=await fixture(),db=user('guess');
 await assertFails(getDoc(doc(db,'invitations',hash(f.role,f.rid,'000000'))));
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'invitations',f.code)));
 await assertFails(getDocs(collection(db,'invitations')));
 await assertFails(getDoc(doc(db,'accountBindings',f.key)));
 await assertFails(getDoc(doc(db,'patientProfiles',f.pid)));
});
test('PIN verifier is context-bound and no raw PIN or email is stored in activation data',async()=>{
 const f=await fixture(),data=(await getDoc(doc(staff(),'invitations',f.code))).data();
 assert.ok(!('pin' in data));assert.ok(!('email' in data));assert.ok(!('password' in data));
 assert.notEqual(hash('relative',f.rid,f.pin),f.code);assert.notEqual(hash(f.role,'OTHER-ID',f.pin),f.code);
});
test('temporary verification sessions and other synthetic IDs cannot claim the owner mapping',async()=>{
 const f=await fixture();await assertFails(claim(f,'helper',user('helper')));
 await assertFails(claim(f,'wrong-id',user('wrong-id','other-id@patient.dialycare.invalid')));
});
test('partial mapping writes, Staff escalation and another Patient claim are denied',async()=>{
 const f=await fixture(),db=owner('partial',f);
 await assertFails(setDoc(doc(db,'users/partial'),{role:f.role,patientId:f.pid,recipientId:f.rid,activationId:f.code,disabled:false,accountStatus:'active',activatedAt:serverTimestamp()}));
 await assertFails(claim(f,'forge-role',owner('forge-role',f),{role:'staff'}));
 await assertFails(claim(f,'forge-patient',owner('forge-patient',f),{patientId:'UNRELATED'}));
});
test('regeneration immediately invalidates the previous pending PIN',async()=>{
 const f=await fixture(),old={...f};do {await issue(f);}while(f.code===old.code);
 await assertFails(getDoc(doc(user('old'),'invitations',old.code)));await assertFails(claim(old,'old'));
 await assertSucceeds(claim(f,'new'));
});
test('Staff cancellation clears pending access; old PIN cannot claim; new access can be created',async()=>{
 const f=await fixture(),old={...f};
 await assertSucceeds(updateDoc(doc(staff(),'accountBindings',f.key),{accountStatus:'notActivated',activationId:null}));
 await assertFails(getDoc(doc(user('cancelled'),'invitations',old.code)));await assertFails(claim(old,'cancelled'));
 await issue(f);await assertSucceeds(claim(f,'after-cancel'));
});
test('expired and revoked PIN records cannot be verified or consumed',async()=>{
 for(const change of [{expiresAt:Timestamp.fromMillis(Date.now()-60000)},{revoked:true}]){
  const f=await fixture();await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'invitations',f.code),change));
  await assertFails(getDoc(doc(user('expired'),'invitations',f.code)));await assertFails(claim(f,'expired-'+f.pid));
 }
});
test('concurrent owners allow one UID; consumed PIN and active reissue are rejected',async()=>{
 const f=await fixture();const results=await Promise.allSettled([claim(f,'race-a'),claim(f,'race-b')]);
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 await assertFails(claim(f,'race-c'));await assertFails(getDoc(doc(user('reuse'),'invitations',f.code)));
 await assertFails(issue({...f}));
});
test('Staff disable and restore retain records; owner cannot self-enable',async()=>{
 const f=await fixture();await assertSucceeds(claim(f,'disabled-owner'));
 await assertSucceeds(updateDoc(doc(staff(),'accountBindings',f.key),{accountStatus:'disabled'}));
 await assertFails(getDoc(doc(owner('disabled-owner',f),'patientProfiles',f.pid)));
 await assertFails(updateDoc(doc(owner('disabled-owner',f),'accountBindings',f.key),{accountStatus:'active'}));
 assert.equal((await getDoc(doc(staff(),'patients',f.pid))).exists(),true);
 await assertSucceeds(updateDoc(doc(staff(),'accountBindings',f.key),{accountStatus:'active'}));
 await assertSucceeds(getDoc(doc(owner('disabled-owner',f),'patientProfiles',f.pid)));
});
test('retired Relative relationship revokes both pending activation and active access',async()=>{
 for(const activated of [false,true]){
  const f=await fixture('relative');if(activated)await assertSucceeds(claim(f,'relative-'+f.pid));
  await assertSucceeds(updateDoc(doc(staff(),'patientRelativeLinks',f.rid+'_'+f.pid),{active:false}));
  if(activated)await assertFails(getDoc(doc(owner('relative-'+f.pid,f),'patientProfiles',f.pid)));
  else await assertFails(claim(f,'retired-'+f.pid));
 }
});


test('activation requires current separate acceptance versions with server timestamps',async()=>{
 const f=await fixture();
 await assertFails(claim(f,'old-terms',owner('old-terms',f),{},{termsVersion:'old-version'}));
 await assertFails(claim(f,'old-privacy',owner('old-privacy',f),{},{privacyNoticeVersion:'old-version'}));
 await assertFails(claim(f,'client-date',owner('client-date',f),{},{termsAcceptedAt:'client-clock'}));
 await assertFails(claim(f,'fingerprint',owner('fingerprint',f),{},{deviceFingerprint:'not-needed'}));
 const uid='accepted-owner';await assertSucceeds(claim(f,uid));
 await assertSucceeds(getDoc(doc(owner(uid,f),'policyAcceptances',uid)));
 await assertFails(getDoc(doc(user('other-reader'),'policyAcceptances',uid)));
 await assertFails(updateDoc(doc(owner(uid,f),'policyAcceptances',uid),{termsVersion:'changed'}));
});
