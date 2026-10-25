"use strict";
const crypto=require('node:crypto');
const PROJECT='dialycare-backend-3f0ed';
const ROOT=`projects/${PROJECT}/databases/(default)/documents`;
const URL='https://firestore.googleapis.com/v1/'+ROOT;
function verifyPublishedRules(request,expectedSource){
 const release=request(`https://firebaserules.googleapis.com/v1/projects/${PROJECT}/releases/cloud.firestore`);
 if(!release.rulesetName?.startsWith(`projects/${PROJECT}/rulesets/`))throw Error('Unexpected published Rules project; migration stopped before writes.');
 const rules=request('https://firebaserules.googleapis.com/v1/'+release.rulesetName);
 const deployed=rules.source?.files?.find(f=>f.content.includes('service cloud.firestore'))?.content;
 const normalize=s=>s?.replace(/^\uFEFF/,'').replace(/\r\n/g,'\n').trim();
 if(!deployed||normalize(deployed)!==normalize(expectedSource))throw Error('Published Rules do not match the reviewed local policy. Migration stopped before writes; reconcile the active policy first.');
}
const decode=v=>v?.stringValue??(v?.integerValue!==undefined?Number(v.integerValue):v?.booleanValue??v?.timestampValue??null);
const data=d=>Object.fromEntries(Object.entries(d.fields||{}).map(([k,v])=>[k,decode(v)]));
const key=d=>d.name.split('/').pop();
const encode=v=>v===null?{nullValue:null}:typeof v==='number'?{integerValue:String(v)}:{stringValue:String(v)};
function write(path,fields,old){return {update:{name:ROOT+'/'+path,fields:Object.fromEntries(Object.entries(fields).map(([k,v])=>[k,encode(v)]))},...(old?{updateMask:{fieldPaths:Object.keys(fields)}}:{}),currentDocument:old?{updateTime:old.updateTime}:{exists:false}};}
function canonical(value,year){
 let m=/^DP-([1-9][0-9]{3})-([0-9]{3,4})$/.exec(value||'');
 if(m){const n=Number(m[2]);if(n>=1&&n<=999)return {id:`DP-${m[1]}-${String(n).padStart(3,'0')}`,year:Number(m[1]),number:n};}
 m=/^DC-([0-9]{1,6})$/.exec(value||'');
 if(m&&Number(m[1])>=1&&Number(m[1])<=999)return {id:`DP-${year}-${String(Number(m[1])).padStart(3,'0')}`,year,number:Number(m[1])};
 return null;
}
function buildPlan(snapshot,year=2026){
 if(year!==2026)throw Error('Existing-record migration issuance year must be explicitly reviewed: 2026.');
 const writes=[],mapping=[],conflicts=[],byInternal=new Map(),targets=new Map();
 const reservations=new Map((snapshot.publicIds||[]).map(d=>[key(d),d]));
 const counters=new Map((snapshot.idCounters||[]).map(d=>[key(d),d]));
 const next=new Map();
 for(const d of snapshot.patients||[]){
  const p=data(d),internal=key(d),old=p.publicId||internal,c=canonical(old,year);
  if(!c){conflicts.push({oldId:old,reason:'Unrecognized ID or sequence exceeds 999; manual mapping required.'});continue;}
  if(targets.has(c.id)&&targets.get(c.id)!==internal){conflicts.push({oldId:old,proposedId:c.id,reason:'Duplicate canonical target.'});continue;}
  targets.set(c.id,internal);byInternal.set(internal,c);
  const reservation=reservations.get(c.id);
  if(reservation&&(data(reservation).internalId!==internal||data(reservation).role!=='patient')){conflicts.push({oldId:old,proposedId:c.id,reason:'Target permanently reserved for another identity.'});continue;}
  mapping.push({oldId:old,newId:c.id,changed:old!==c.id});
  next.set(c.year,Math.max(next.get(c.year)||1,c.number+1));
  if(old!==c.id)writes.push(write('patients/'+internal,{publicId:c.id,idIssuanceYear:c.year},d));
  if(!reservation)writes.push(write('publicIds/'+c.id,{role:'patient',internalId:internal,publicId:c.id,year:c.year,sequence:c.number}));
  const profile=(snapshot.patientProfiles||[]).find(x=>key(x)===internal);
  if(!profile){conflicts.push({oldId:old,reason:'Missing authorized coordination profile; repair before migration.'});continue;}
  if(data(profile).publicId!==c.id)writes.push(write('patientProfiles/'+internal,{publicId:c.id,syncVersion:crypto.createHash('sha256').update('canonical-patient-v1:'+internal+':'+c.id).digest('hex')},profile));
 }
 // Reservations for retired identities also keep the issuance sequence consumed.
 for(const d of snapshot.publicIds||[]){const r=data(d);if(r.role!=='patient')continue;const c=canonical(r.publicId||key(d),year);if(c)next.set(c.year,Math.max(next.get(c.year)||1,c.number+1));}
 for(const [y,n]of next){
  const old=counters.get('patients-'+y),current=old?data(old).nextPatientNumber:1,target=Math.max(current,n);
  if(target>1000){conflicts.push({reason:'Yearly counter exceeds three-digit capacity.'});continue;}
  if(!old||current!==target)writes.push(write('idCounters/patients-'+y,{year:y,nextPatientNumber:target},old));
 }
 for(const d of snapshot.invitations||[]){
  const v=data(d);if(v.usedBy||v.revoked)continue;
  const p=byInternal.get(v.patientId);if(!p){conflicts.push({reason:'A pending invitation references an unmapped Patient.'});continue;}
  const change={};if(v.patientPublicId!==p.id)change.patientPublicId=p.id;
  if(v.role==='patient'&&v.publicId!==p.id)change.publicId=p.id;
  if(Object.keys(change).length)writes.push(write(d.name.slice(ROOT.length+1),change,d));
 }
 let patientAuthMappings=0;
 for(const d of snapshot.users||[]){
  const u=data(d);if(!['patient','relative'].includes(u.role))continue;
  if(!byInternal.has(u.patientId)){conflicts.push({reason:'A Mobile account refers to an unmapped Patient.'});continue;}
  const binding=(snapshot.accountBindings||[]).find(b=>key(b)===u.role+'_'+u.recipientId);
  if(!binding||data(binding).uid!==key(d))conflicts.push({reason:'Mobile account/binding ownership mismatch.'});
  if(u.role==='patient')patientAuthMappings++;
 }
 const state=(snapshot.clinical||[]).find(d=>key(d)==='state');
 if(writes.length&&state)writes.push(write('clinical/state',{revision:Number(data(state).revision||0)+1},state));
 if(writes.length>450)conflicts.push({reason:'Atomic plan exceeds reviewed batch limit; no chunked apply allowed.'});
 const related={};
 for(const [collection,docs]of Object.entries(snapshot)){
  if(['patients','publicIds','idCounters','clinical'].includes(collection))continue;
  related[collection]={records:docs.length,patientReferences:docs.filter(d=>byInternal.has(data(d).patientId)||byInternal.has(data(d).recipientId)||(['patientProfiles','patientAccountProfiles'].includes(collection)&&byInternal.has(key(d)))).length};
 }
 const plan={version:1,project:PROJECT,issuanceYear:year,patientCount:(snapshot.patients||[]).length,patientsToChange:mapping.filter(m=>m.changed).length,mapping,conflicts,
  nextByYear:Object.fromEntries([...next].map(([y,n])=>[y,Math.max(n,data(counters.get('patients-'+y)||{}).nextPatientNumber||1)])),
  related,patientAuthMappings,authAccountsChanged:0,documentIdsRenamed:0,foreignKeysRewritten:0,
  firestoreWrites:writes.length,preservesOriginalMessages:true,preservesAuthUidsAndPasswords:true};
 const digest=crypto.createHash('sha256').update(JSON.stringify({plan,writes})).digest('hex');
 return {plan:{...plan,digest},writes};
}
async function readSnapshot(request){
 const fields={patients:['id','publicId','createdAt','idIssuanceYear'],patientProfiles:['id','publicId','syncVersion'],
 patientAccountProfiles:['id'],publicIds:['role','internalId','publicId','year','sequence'],idCounters:['year','nextPatientNumber'],clinical:['revision'],
 users:['role','patientId','recipientId','accountStatus','disabled'],accountBindings:['uid','role','patientId','recipientId','accountStatus','activationId'],
 invitations:['role','recipientId','patientId','publicId','patientPublicId','usedBy','revoked'],
 relatives:['id','publicId'],patientRelativeLinks:['patientId','relativeId','active'],sessions:['patientId'],sessionEvents:['patientId','sessionId'],notifications:['patientId','recipientId','recipientType','sessionId'],feedbackConcerns:['patientId','submittedByUid','submitterRole','recipientId'],scheduleHistory:['patientId','sessionId']};
 const result={};
 for(const [collection,selection]of Object.entries(fields)){
  const raw=request(URL+':runQuery','POST',{structuredQuery:{from:[{collectionId:collection}],select:{fields:selection.map(fieldPath=>({fieldPath}))}}});
  result[collection]=(Array.isArray(raw)?raw:[raw]).filter(r=>r.document).map(r=>r.document);
 }
 return result;
}
async function main(){
 const {connect}=require('./inspect-database-powershell.cjs');
 const request=await connect(),snapshot=await readSnapshot(request),{plan,writes}=buildPlan(snapshot);
 // Auth remains unchanged. Validate compatibility rather than modifying aliases.
 for(const d of snapshot.users){const u=data(d);if(u.role!=='patient')continue;
  const p=snapshot.patients.find(p=>key(p)===u.patientId);if(!p)continue;
  const c=canonical(data(p).publicId||key(p),2026);if(!c)continue;
  const lookup=request(`https://identitytoolkit.googleapis.com/v1/projects/${PROJECT}/accounts:lookup`,'POST',{localId:[key(d)]});
  const allowed=new Set([c.id,`DP-${c.year}-${String(c.number).padStart(4,'0')}`,
    ...(c.year===2026?[`DC-${String(c.number).padStart(6,'0')}`,`DC-${String(c.number).padStart(3,'0')}`]:[])].map(id=>id.toLowerCase()+'@patient.dialycare.invalid'));
  if(!lookup.users?.[0]||!allowed.has(lookup.users[0].email))plan.conflicts.push({reason:'Existing Patient Auth alias is not compatible with the bounded migration login mapping.'});
 }
 for(const d of snapshot.invitations){const inv=data(d);if(inv.role!=='patient'||inv.usedBy||inv.revoked)continue;
  const binding=snapshot.accountBindings.find(b=>key(b)==='patient_'+inv.recipientId);
  const found=request(`https://identitytoolkit.googleapis.com/v1/projects/${PROJECT}/accounts:lookup`,'POST',{email:[String(inv.publicId||inv.recipientId).toLowerCase()+'@patient.dialycare.invalid']});
  if(found.users?.some(a=>a.localId!==data(binding||{}).uid))plan.conflicts.push({reason:'A pending activation has an existing unbound Auth identity; complete/review activation before migration.'});
 }
 console.log(JSON.stringify(plan,null,2));
 if(!process.argv.includes('--apply'))return;
 const approved=process.argv.find(x=>x.startsWith('--approved-digest='))?.split('=')[1];
 if(!approved||approved!==plan.digest||plan.conflicts.length)throw Error('Apply requires an explicitly approved matching dry-run digest and zero conflicts.');
 require('./patient-migration-integrity.cjs').requireIntegrity(snapshot);
 verifyPublishedRules(request,require('node:fs').readFileSync(require('node:path').join(__dirname,'firestore.spark.rules'),'utf8'));
 if(writes.length)request(URL+':commit','POST',{writes});
 const verified=buildPlan(await readSnapshot(request)).plan;
 if(verified.conflicts.length||verified.patientsToChange||verified.firestoreWrites)throw Error('Post-migration verification requires trusted review; no records were deleted.');
 console.log('CANONICAL_PATIENT_IDS_VERIFIED; Auth accounts/passwords and internal references unchanged.');
}
module.exports={canonical,buildPlan,readSnapshot,data,ROOT,verifyPublishedRules};
if(require.main===module)main().catch(e=>{console.error(e.message);process.exitCode=1;});
