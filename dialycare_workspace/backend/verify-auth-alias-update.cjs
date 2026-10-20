'use strict';
const {connect}=require('./inspect-database-powershell.cjs');
const {randomBytes}=require('node:crypto');
const fs=require('node:fs');
(async()=>{
 const request=await connect(),project='dialycare-backend-3f0ed';
 const key=fs.readFileSync('../dialycare_staff/lib/firebase_options.dart','utf8').match(/apiKey:\s*'([^']+)'/)[1];
 const nonce=randomBytes(8).toString('hex'),password=randomBytes(12).toString('base64url');
 const email='verify-alias-'+nonce+'@patient.dialycare.invalid',next='verify-updated-'+nonce+'@patient.dialycare.invalid';
 const auth=(action,body)=>request('https://identitytoolkit.googleapis.com/v1/accounts:'+action+'?key='+key,'POST',body,'');
 let uid;
 try{
  const created=auth('signUp',{email,password,returnSecureToken:true});uid=created.localId;
  request(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts:update`,'POST',{localId:uid,email:next});
  const login=auth('signInWithPassword',{email:next,password,returnSecureToken:true});
  if(login.localId!==uid)throw Error('Alias change did not preserve the test identity.');
  console.log('AUTH_ALIAS_UPDATE_VERIFIED: same UID and same chosen password; no password update or reset was performed.');
 }finally{if(uid){request(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts:delete`,'POST',{localId:uid});console.log('Disposable alias test account removed.');}}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
