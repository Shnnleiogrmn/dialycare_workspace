'use strict';
// Trusted, manually run migration for the existing single center. No credentials
// are persisted and no document IDs, UID mappings, sessions or links are renamed.
const {connect}=require('./inspect-database-powershell.cjs');
const {randomBytes}=require('node:crypto');
const project='dialycare-backend-3f0ed';
const root=`projects/${project}/databases/(default)/documents`,url='https://firestore.googleapis.com/v1/'+root;
function encode(v){if(v===null)return {nullValue:null};if(typeof v==='boolean')return {booleanValue:v};if(typeof v==='number')return {integerValue:String(v)};return {stringValue:String(v)};}
function decode(v){if('stringValue'in v)return v.stringValue;if('integerValue'in v)return Number(v.integerValue);if('booleanValue'in v)return v.booleanValue;if('nullValue'in v)return null;return undefined;}
const values=d=>Object.fromEntries(Object.entries(d.fields||{}).map(([k,v])=>[k,decode(v)]));
const doc=(p,data)=>({name:root+'/'+p,fields:Object.fromEntries(Object.entries(data).map(([k,v])=>[k,encode(v)]))});
async function main(){
 const apply=process.argv.includes('--apply');
 const request=await connect();
 function get(p){try{return request(url+'/'+p);}catch(e){if(e.message.includes('404'))return null;throw e;}}
 function query(collection,fields){const result=request(url+':runQuery','POST',{structuredQuery:{from:[{collectionId:collection}],select:{fields:fields.map(fieldPath=>({fieldPath}))}}});return (Array.isArray(result)?result:[result]).filter(r=>r.document).map(r=>r.document);}
 const patients=query('patients',['id','name','contact','publicId']);
 const relatives=query('relatives',['id','name','publicId']);
 const links=query('patientRelativeLinks',['patientId','relativeId','relationship','active']);
 const profiles=query('patientProfiles',['id','name','publicId','syncVersion']);
 const privateProfiles=query('patientAccountProfiles',['id','contact','relativeName','relationship']);
 const reservations=query('publicIds',['role','internalId','publicId']);
 const bindings=query('accountBindings',['role','recipientId','patientId','uid','accountStatus']);
 const users=query('users',['role','recipientId','patientId','accountStatus','disabled']);
 const invitations=query('invitations',['role','recipientId','patientId','publicId','patientPublicId','usedBy','revoked']);
 const state=get('clinical/state'),counterDoc=get('idCounters/center');
 const counter=counterDoc?values(counterDoc):{};
 const next={patient:counter.nextPatientNumber||1,relative:counter.nextRelativeNumber||1};
 for(const d of reservations){const v=values(d);if(['patient','relative'].includes(v.role)&&typeof v.publicId==='string'){const n=Number(v.publicId.slice(v.role==='patient'?3:2));if(Number.isInteger(n))next[v.role]=Math.max(next[v.role],n+1);}}
 const allocated=new Map(),byInternal=new Map();
 const recordLists={patient:patients,relative:relatives};
 const publicId=(role,n)=>{if(n<1||n>999999)throw Error('Center ID range exhausted.');return (role==='patient'?'DC-':'R-')+String(n).padStart(6,'0');};
 // Reserve existing published IDs first; then retain the numeric legacy Patient
 // numbers where possible. Every retired Relative participates in allocation.
 for(const role of ['patient','relative'])for(const d of recordLists[role]){
  const v=values(d),internal=v.id||d.name.split('/').pop();
  let id=v.publicId;
  if(!id&&role==='patient'&&/^DC-\d{1,6}$/.test(internal)&&Number(internal.slice(3))>0)id=publicId(role,Number(internal.slice(3)));
  if(!id)continue;
  if(!(role==='patient'?/^DC-[0-9]{6}$/:/^R-[0-9]{6}$/).test(id)||id.endsWith('-000000'))throw Error('Invalid existing public ID; no changes made.');
  if(allocated.has(id)&&allocated.get(id)!==internal)throw Error('Conflicting public IDs; no changes made.');
  allocated.set(id,internal);byInternal.set(role+':'+internal,id);
  next[role]=Math.max(next[role],Number(id.slice(role==='patient'?3:2))+1);
 }
 if(state)next.patient=Math.max(next.patient,values(state).nextPatientNumber||1);
 for(const role of ['patient','relative'])for(const d of [...recordLists[role]].sort((a,b)=>a.name.localeCompare(b.name))){
  const v=values(d),internal=v.id||d.name.split('/').pop(),key=role+':'+internal;
  if(byInternal.has(key))continue;
  const id=publicId(role,next[role]++);allocated.set(id,internal);byInternal.set(key,id);
 }
 const knownReservations=new Map(reservations.map(d=>[d.name.split('/').pop(),values(d)]));
 const writes=[],plan=[];
 for(const role of ['patient','relative'])for(const d of recordLists[role]){
  const v=values(d),internal=v.id||d.name.split('/').pop(),id=byInternal.get(role+':'+internal);
  plan.push({role,internalId:internal,publicId:id});
  if(v.publicId!==id)writes.push({update:doc((role==='patient'?'patients/':'relatives/')+internal,{publicId:id}),updateMask:{fieldPaths:['publicId']},currentDocument:{updateTime:d.updateTime}});
  const reservation=knownReservations.get(id);
  if(reservation&&(reservation.role!==role||reservation.internalId!==internal))throw Error('An ID belongs to another record; no changes made.');
  if(!reservation)writes.push({update:doc('publicIds/'+id,{role,internalId:internal,publicId:id}),currentDocument:{exists:false}});
 }
 for(const p of patients){
  const v=values(p),id=v.id||p.name.split('/').pop();
  const existing=profiles.find(d=>values(d).id===id);
  writes.push({update:doc('patientProfiles/'+id,{...(existing?{}:{id,name:v.name||''}),publicId:byInternal.get('patient:'+id),syncVersion:randomBytes(16).toString('hex')}),...(existing?{updateMask:{fieldPaths:['publicId','syncVersion']}}:{}),currentDocument:existing?{updateTime:existing.updateTime}:{exists:false}});
  const link=links.map(values).find(l=>l.patientId===id&&l.active);
  const relative=link?relatives.map(values).find(r=>r.id===link.relativeId):null;
  const old=privateProfiles.find(d=>values(d).id===id);
  writes.push({update:doc('patientAccountProfiles/'+id,{id,contact:v.contact||'',relativeName:relative?.name||'',relationship:link?.relationship||''}),currentDocument:old?{updateTime:old.updateTime}:{exists:false}});
 }
 // Existing PIN hashes are preserved. Old pending ID+PIN pairs remain usable;
 // newly generated PINs bind to the new center ID. Consumed invitations are intact.
 for(const d of invitations){const v=values(d);if(v.usedBy||v.revoked)continue;const id=byInternal.get(v.role+':'+v.recipientId),pid=byInternal.get('patient:'+v.patientId);if(id&&pid)writes.push({update:doc(d.name.substring(root.length+1),{publicId:id,patientPublicId:pid}),updateMask:{fieldPaths:['publicId','patientPublicId']},currentDocument:{updateTime:d.updateTime}});}
 writes.push({update:doc('idCounters/center',{nextPatientNumber:next.patient,nextRelativeNumber:next.relative}),currentDocument:counterDoc?{updateTime:counterDoc.updateTime}:{exists:false}});
 if(state)writes.push({update:doc('clinical/state',{revision:Date.now()*1000,nextPatientNumber:next.patient,nextRelativeNumber:next.relative}),updateMask:{fieldPaths:['revision','nextPatientNumber','nextRelativeNumber']},currentDocument:{updateTime:state.updateTime}});
 if(writes.length>450)throw Error('Migration exceeds one atomic batch; prepare a reviewed chunked migration before applying.');
 const aliases=[];
 for(const d of users){
  const u=values(d);if(!['patient','relative'].includes(u.role))continue;
  const uid=d.name.split('/').pop(),binding=bindings.map(values).find(b=>b.role===u.role&&b.recipientId===u.recipientId&&b.uid===uid);
  if(!binding)throw Error('A Mobile mapping lacks its authoritative binding; no changes made.');
  const id=byInternal.get(u.role+':'+u.recipientId);if(!id)throw Error('A Mobile mapping lacks its care record; no changes made.');
  const result=request(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts:lookup`,'POST',{localId:[uid]});
  const account=result.users?.[0];if(!account||account.localId!==uid)throw Error('An activated Auth identity is unavailable.');
  const old=u.recipientId.toLowerCase()+'@'+u.role+'.dialycare.invalid',desired=id.toLowerCase()+'@'+u.role+'.dialycare.invalid';
  if(account.email!==old&&account.email!==desired)throw Error('Unexpected Mobile Auth identifier; trusted review required before migration.');
  if(account.email!==desired){
   const collision=request(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts:lookup`,'POST',{email:[desired]});
   if(collision.users?.some(a=>a.localId!==uid))throw Error('The target Auth alias is already reserved; no changes made.');
   aliases.push({uid,role:u.role,publicId:id,email:desired});
  }
 }
 console.log(JSON.stringify({mode:apply?'apply':'preview',project,records:plan,nextPatientNumber:next.patient,nextRelativeNumber:next.relative,firestoreWrites:writes.length,authAliasesToUpdate:aliases.map(a=>({uid:a.uid,role:a.role,publicId:a.publicId})),preservesDocumentIds:true,preservesAuthUidsAndPasswords:true}));
 if(!apply)return;
 request(url+':commit','POST',{writes});
 for(const alias of aliases){
  // Update ONLY the technical sign-in alias. No password, UID, binding, role,
  // provider, acceptance record, refresh-token validity or MFA field is sent.
  const result=request(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts:update`,'POST',{localId:alias.uid,email:alias.email});
  if(result.localId&&result.localId!==alias.uid)throw Error('Unexpected Auth migration result.');
  const verified=request(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts:lookup`,'POST',{localId:[alias.uid]});
  if(verified.users?.[0]?.email!==alias.email)throw Error('Auth alias verification failed; rerun the idempotent migration.');
 }
 console.log('ID_MIGRATION_APPLIED_AND_AUTH_ALIASES_VERIFIED. Existing passwords were never requested or changed.');
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
