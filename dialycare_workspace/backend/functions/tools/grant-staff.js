'use strict';
// Run only in a trusted administrator environment using Application Default Credentials.
const {initializeApp}=require('firebase-admin/app');const {getAuth}=require('firebase-admin/auth');
initializeApp({projectId:'dialycare-backend-3f0ed'});
const uid=process.argv[2];if(!uid){console.error('Usage: node tools/grant-staff.js FIREBASE_AUTH_UID');process.exit(1);}
(async()=>{const user=await getAuth().getUser(uid);await getAuth().setCustomUserClaims(uid,{...user.customClaims,staff:true});console.log('Staff role assigned. Sign out and back in to refresh authorization.');})().catch(e=>{console.error(e.code||'Unable to assign staff role.');process.exit(1);});
