'use strict';
const {onRequest} = require('firebase-functions/v2/https');
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore,FieldValue} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');
const {randomBytes,createHash} = require('node:crypto');
initializeApp();
const db=getFirestore(),auth=getAuth(),state=db.doc('clinical/state');
const hash=v=>createHash('sha256').update(v).digest('hex');
const fail=(status,message)=>{const e=new Error(message);e.status=status;throw e;};
const empty=()=>({version:2,patients:[],sessions:[],notifications:[],deliveryHistory:[],notificationEvents:[],staffName:'Staff',passwordSalt:'',passwordHash:''});
const validId=v=>typeof v==='string'&&/^[a-z0-9-]{2,100}$/i.test(v);
const accountEmail=(role,id)=>`${id.toLowerCase()}@${role}.dialycare.invalid`;
async function user(req){const m=/^Bearer (.+)$/.exec(req.headers.authorization||'');if(!m)fail(401,'Please log in.');try{return await auth.verifyIdToken(m[1],true);}catch(_){fail(401,'Please log in again.');}}
async function linked(u){const d=await db.doc(`users/${u.uid}`).get();if(!d.exists||!['patient','relative'].includes(d.data().role)||d.data().disabled)fail(403,'Your account is not linked. Contact your care center.');return d.data();}
function staff(u){if(u.staff!==true)fail(403,'Authorized staff access required.');}
async function clinical(){const d=await state.get();return d.exists?d.data():{revision:0,bundle:empty()};}
async function currentLink(u){const link=await linked(u),record=await clinical(),p=record.bundle.patients.find(p=>p.id===link.patientId);const person=link.role==='patient'?p:p?.companions?.find(c=>c.id===link.recipientId);if(!person)fail(403,'Your care center must update your account link.');return {link,record,p,person};}
async function devices(uid){const rows=await db.collection('devices').where('uid','==',uid).get();return rows.docs.filter(d=>d.data().enabled&&Date.now()-d.data().seen<30*86400000);}
async function decorate(bundle){const copy=structuredClone(bundle),users=await db.collection('users').get();
 for(const p of copy.patients){for(const [role,person] of [['patient',p],...(p.companions||[]).map(c=>['relative',c])]){
  const owner=users.docs.find(d=>!d.data().disabled&&d.data().role===role&&d.data().patientId===p.id&&d.data().recipientId===person.id);
  const rows=owner?await devices(owner.id):[];
  person.registration={status:rows.length?'connected':owner?'unavailable':'notRegistered',pushToken:rows.length?'backend-managed':'',backendVerified:true,notificationsEnabled:true,lastActivity:rows.length?new Date(Math.max(...rows.map(d=>d.data().seen))).toISOString():null};
 }}return copy;
}
async function register(body,req){const {role,id,password,invite}=body;
 if(!['patient','relative'].includes(role)||!validId(id)||typeof password!=='string'||password.length<8||password.length>128||typeof invite!=='string'||invite.length>128)fail(400,'Check your registration details.');
 // Invitation secrets have 192 bits of entropy. No public patient lookup endpoint.
 const ref=db.doc(`invitations/${hash(invite)}`);const attempt=randomBytes(16).toString('hex');let invitation;
 await db.runTransaction(async tx=>{const d=await tx.get(ref);invitation=d.data();if(!invitation||invitation.used||invitation.expires<Date.now()||invitation.role!==role||invitation.id.toLowerCase()!==id.toLowerCase())fail(403,'Invalid or expired invitation. Contact your care center.');tx.update(ref,{used:true,claim:attempt});});
 let created;
 try{
  const bundle=(await clinical()).bundle,p=bundle.patients.find(p=>p.id===invitation.patientId),person=role==='patient'?p:p?.companions?.find(c=>c.id===invitation.id);
  if(!person)fail(403,'This invitation is no longer valid. Contact your care center.');
  created=await auth.createUser({email:accountEmail(role,id),password,displayName:person.name});
  await db.doc(`users/${created.uid}`).create({role,patientId:invitation.patientId,recipientId:invitation.id,name:person.name,disabled:false});
  await ref.update({uid:created.uid});return {ok:true};
 }catch(e){if(created)await auth.deleteUser(created.uid).catch(()=>{});await db.runTransaction(async tx=>{const d=await tx.get(ref);if(d.data()?.claim===attempt)tx.update(ref,{used:false,claim:FieldValue.delete()});});if(e.status)throw e;fail(409,'Unable to create this account. Contact your care center.');}
}
exports.api=onRequest({region:'us-central1',timeoutSeconds:60,cors:false},async(req,res)=>{
 res.set('Cache-Control','no-store');if(req.method!=='POST')return res.status(405).json({error:'POST required.'});
 try{
 const action=req.path.split('/').filter(Boolean).pop(),b=req.body||{};
 if(action==='register')return res.json(await register(b,req));
 const u=await user(req);
 if(action==='staffData'){staff(u);const r=await clinical();return res.json({revision:r.revision,bundle:await decorate(r.bundle)});}
 if(action==='staffSave'){staff(u);const bundle=b.bundle;
  if(!bundle||!Array.isArray(bundle.patients)||!Array.isArray(bundle.sessions)||!Array.isArray(bundle.deliveryHistory)||!Array.isArray(bundle.notificationEvents)||!Array.isArray(bundle.notifications))fail(400,'Invalid workspace.');
  const ids=new Set(bundle.patients.map(p=>p.id));if(ids.size!==bundle.patients.length||bundle.patients.some(p=>!validId(p.id))||new Set(bundle.sessions.map(s=>s.id)).size!==bundle.sessions.length||bundle.sessions.some(s=>!ids.has(s.patientId)||!['Pending','In Progress','Completed','Ready for Pick Up','Missed','Waiting','Cancelled'].includes(s.status)))fail(400,'Invalid patient or session records.');
  // Auth credentials and device registration are never accepted from the Staff UI.
  const clean=structuredClone(bundle);delete clean.passwordSalt;delete clean.passwordHash;
  for(const p of clean.patients){delete p.registration;for(const c of p.companions||[])delete c.registration;}
  if(Buffer.byteLength(JSON.stringify(clean))>850000)fail(413,'Workspace storage limit reached. Contact your administrator before adding more records.');
  const revision=await db.runTransaction(async tx=>{const old=await tx.get(state),r=old.exists?old.data().revision:0;if(r!==b.revision)fail(409,'The workspace changed. Refresh before saving.');tx.set(state,{revision:r+1,bundle:clean,updatedBy:u.uid,updatedAt:FieldValue.serverTimestamp()});return r+1;});return res.json({revision});
 }
 if(action==='invite'){staff(u);const {role,id,patientId}=b;const p=(await clinical()).bundle.patients.find(p=>p.id===patientId);if(!['patient','relative'].includes(role)||!p||(role==='patient'?p.id!==id:!p.companions?.some(c=>c.id===id)))fail(400,'Select an existing patient or designated relative.');
  const code=randomBytes(24).toString('base64url');await db.doc(`invitations/${hash(code)}`).create({id,role,patientId,expires:Date.now()+24*3600000,used:false,issuedBy:u.uid});return res.json({code,expiresHours:24});
 }
 if(action==='revokeDevice'){
  if(typeof b.token!=='string'||b.token.length<20||b.token.length>4096)fail(400,'Invalid device registration.');
  const ref=db.doc(`devices/${hash(b.token)}`);await db.runTransaction(async tx=>{const d=await tx.get(ref);if(d.data()?.uid===u.uid)tx.update(ref,{enabled:false});});return res.json({ok:true});
 }
 const {link,record,p,person}=action==='dispatch'?{link:null}:await currentLink(u);
 if(action==='mobileData'){if(b.role && b.role!==link.role)fail(403,'Use the role assigned to your account.');
  const reads=await db.collection(`users/${u.uid}/reads`).get(),readAt=new Map(reads.docs.map(d=>[d.id,d.data().readAt]));
  const history=record.bundle.deliveryHistory.filter(n=>n.patientId===link.patientId&&n.recipientId===link.recipientId&&n.recipientType===link.role).map(n=>({id:n.id,patientId:n.patientId,type:n.type,title:n.title,message:n.message,createdAt:n.createdAt,readAt:readAt.get(n.id)||null,deliveryStatus:n.attempts?.at(-1)?.status||'pending',deliveryChannel:n.attempts?.at(-1)?.channel||null})).sort((a,b)=>b.createdAt.localeCompare(a.createdAt));
  return res.json({profile:{name:person.name,patientName:p.name,patientId:p.id,role:link.role},sessions:record.bundle.sessions.filter(s=>s.patientId===link.patientId),notifications:history});
 }
 if(action==='readNotification'){if(!record.bundle.deliveryHistory.some(n=>n.id===b.id&&n.patientId===link.patientId&&n.recipientId===link.recipientId&&n.recipientType===link.role))fail(403,'Notification unavailable.');await db.doc(`users/${u.uid}/reads/${b.id}`).set({readAt:new Date().toISOString()});return res.json({ok:true});}
 if(action==='registerDevice'||action==='revokeDevice'){if(typeof b.token!=='string'||b.token.length<20||b.token.length>4096)fail(400,'Invalid device registration.');const ref=db.doc(`devices/${hash(b.token)}`);
  if(action==='registerDevice')await ref.set({uid:u.uid,token:b.token,enabled:true,seen:Date.now(),role:link.role,recipientId:link.recipientId,patientId:link.patientId});
  else await db.runTransaction(async tx=>{const d=await tx.get(ref);if(d.data()?.uid===u.uid)tx.update(ref,{enabled:false});});return res.json({ok:true});
 }
 if(action==='dispatch'){staff(u);return res.json(await dispatch(b));}
 fail(404,'Unknown request.');
 }catch(e){console.error('API failure',e.code||e.status||'internal');res.status(e.status||500).json({error:e.status?e.message:'Unable to complete this request. Please try again.'});}
});
async function dispatch(b){
 const r=await clinical(),delivery=r.bundle.deliveryHistory.find(n=>`${n.id}:${b.channel}`===b.key);
 if(!delivery||!['push','sms'].includes(b.channel))fail(400,'Persist the notification before sending it.');
 // Resolve recipients server-side, never trust a client-provided token or number.
 const p=r.bundle.patients.find(p=>p.id===delivery.patientId),person=delivery.recipientType==='patient'?p:p?.companions?.find(c=>c.id===delivery.recipientId);
 if(!person)fail(409,'Recipient no longer exists.');
 const receipt=db.doc(`deliveryReceipts/${hash(b.key)}`);let prior;
 await db.runTransaction(async tx=>{const d=await tx.get(receipt);prior=d.data();if(!prior)tx.create(receipt,{status:'pending',reason:'Provider acceptance not yet reconciled.',createdAt:Date.now()});});
 if(prior)return prior;
 let result;
 if(b.channel==='sms'){
  result=await sendSms(person.contact,delivery.message);
 }else{
  const users=await db.collection('users').get(),owner=users.docs.find(d=>!d.data().disabled&&d.data().patientId===delivery.patientId&&d.data().recipientId===delivery.recipientId&&d.data().role===delivery.recipientType);
  const registered=owner?await devices(owner.id):[];
  if(!registered.length)result={status:'failed',reason:'No active app registration.',invalidRegistration:true};
  else{
   try{
    // Keep clinical details in authenticated history; lock-screen text stays generic.
    const response=await getMessaging().sendEachForMulticast({tokens:registered.map(d=>d.data().token),notification:{title:'DialyCare',body:'You have a new care-center notification.'},data:{notificationId:delivery.id}});
    const invalid=['messaging/registration-token-not-registered','messaging/invalid-registration-token'];
    await Promise.all(response.responses.map((v,i)=>invalid.includes(v.error?.code)?registered[i].ref.update({enabled:false}):null));
    result=response.successCount?{status:'sent',providerId:response.responses.find(v=>v.success).messageId,reason:'Accepted by FCM; device delivery is not confirmed.'}:response.responses.every(v=>invalid.includes(v.error?.code))?{status:'failed',invalidRegistration:true,reason:'App registration is no longer valid.'}:{status:'pending',reason:'Push acceptance requires server reconciliation; SMS was not attempted.'};
   }catch(_){result={status:'pending',reason:'Push acceptance is unknown; reconcile before retrying.'};}
  }
 }
 await receipt.set(result);return result;
}

async function sendSms(destination,message){
 const sid=process.env.TWILIO_ACCOUNT_SID,secret=process.env.TWILIO_AUTH_TOKEN,from=process.env.TWILIO_FROM;
 if(!sid||!secret||!from)return {status:'failed',reason:'SMS provider requires manual server configuration.'};
 if(!/^AC[a-f0-9]{32}$/i.test(sid)||!/^\+[1-9][0-9]{7,14}$/.test(destination||''))return {status:'failed',reason:'A valid E.164 recipient number is required.'};
 try{
  const response=await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`,{method:'POST',headers:{Authorization:`Basic ${Buffer.from(`${sid}:${secret}`).toString('base64')}`,'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({To:destination,From:from,Body:message}),signal:AbortSignal.timeout(20000)});
  if(response.status===429||response.status>=500)return {status:'pending',reason:'SMS acceptance requires provider reconciliation.'};
  if(!response.ok)return {status:'failed',reason:'SMS provider rejected the request.'};
  const data=await response.json();return {status:'sent',providerId:data.sid,reason:'Accepted by SMS provider; delivery is not confirmed.'};
 }catch(_){return {status:'pending',reason:'SMS acceptance is unknown; reconcile before retrying.'};}
}
