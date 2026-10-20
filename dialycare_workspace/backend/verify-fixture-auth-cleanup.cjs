"use strict";
const {connect}=require('./inspect-database-powershell.cjs'),{randomBytes}=require('node:crypto'),fs=require('node:fs'),path=require('node:path');
const cleanup=require('./fixture-auth-cleanup.cjs');
(async()=>{
 const r=await connect(),project='dialycare-backend-3f0ed';
 const config=fs.readFileSync(path.resolve(__dirname,'../dialycare_staff/lib/firebase_options.dart'),'utf8'),key=config.match(/apiKey:\s*'([^']+)'/)[1];
 const auth=(action,body)=>r('https://identitytoolkit.googleapis.com/v1/accounts:'+action+'?key='+key,'POST',body,'');
 const credentials={email:'cleanup-'+randomBytes(10).toString('hex')+'@verification.dialycare.invalid',password:randomBytes(20).toString('base64url')};
 const created=auth('signUp',{...credentials,returnSecureToken:true});
 try{
  cleanup(auth,credentials,created.localId);
  const found=r('https://identitytoolkit.googleapis.com/v1/projects/'+project+'/accounts:lookup','POST',{localId:[created.localId]}).users||[];
  if(found.length)throw Error('Owned cleanup verification account remains.');
  console.log('FRESH_REAUTHENTICATION_AND_AUTH_FIXTURE_DELETION_VERIFIED');
 }catch(error){
  const found=r('https://identitytoolkit.googleapis.com/v1/projects/'+project+'/accounts:lookup','POST',{localId:[created.localId]}).users||[];
  if(found.some(u=>u.localId===created.localId&&u.email===credentials.email))r('https://identitytoolkit.googleapis.com/v1/projects/'+project+'/accounts:delete','POST',{localId:created.localId});
  throw error;
 }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
