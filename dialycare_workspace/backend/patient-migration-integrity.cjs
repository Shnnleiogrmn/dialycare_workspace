'use strict';
const {data}=require('./canonical-patient-migration.cjs');
const key=d=>d.name.split('/').pop();

// Read-only checks. Keep document identities in the private report, never logs.
function inspectIntegrity(snapshot){
 const ids=c=>new Set((snapshot[c]||[]).map(key));
 const patients=ids('patients'),relatives=ids('relatives'),sessions=ids('sessions'),users=ids('users');
 const issues=[];
 const fail=(collection,d,reason)=>issues.push({collection,document:key(d),reason});
 for(const c of ['patients','relatives'])for(const d of snapshot[c]||[]){const v=data(d);if(v.id&&v.id!==key(d))fail(c,d,'Document key does not match immutable id');}
 for(const c of ['patientProfiles','patientAccountProfiles'])for(const d of snapshot[c]||[])if(!patients.has(key(d)))fail(c,d,'Projection has no Patient');
 for(const d of snapshot.patients||[])for(const c of ['patientProfiles','patientAccountProfiles'])if(!ids(c).has(key(d)))fail('patients',d,'Missing '+c+' projection');
 for(const c of ['patientRelativeLinks','sessions','sessionEvents','notifications','feedbackConcerns','scheduleHistory','invitations','accountBindings'])for(const d of snapshot[c]||[]){
  const v=data(d);
  if(!v.patientId||!patients.has(v.patientId))fail(c,d,'Patient reference does not resolve');
  if(c==='patientRelativeLinks'&&!relatives.has(v.relativeId))fail(c,d,'Relative reference does not resolve');
  if(c==='patientRelativeLinks'&&key(d)!==v.relativeId+'_'+v.patientId)fail(c,d,'Relationship key is incompatible with authorization lookup');
  if(v.sessionId&&!sessions.has(v.sessionId))fail(c,d,'Session reference does not resolve');
  if(v.sessionId&&sessions.has(v.sessionId)){
   const session=(snapshot.sessions||[]).find(s=>key(s)===v.sessionId);
   if(data(session).patientId!==v.patientId)fail(c,d,'Session belongs to another Patient');
  }
  const role=v.role||v.recipientType;
  if(['notifications','invitations','accountBindings'].includes(c)&&['patient','relative'].includes(role)){
   if(role==='patient'&&v.recipientId!==v.patientId)fail(c,d,'Patient recipient mismatch');
   if(role==='relative'&&!relatives.has(v.recipientId))fail(c,d,'Relative recipient does not resolve');
  }
  if(c==='feedbackConcerns'&&v.submittedByUid&&!users.has(v.submittedByUid))fail(c,d,'Feedback submitter account missing');
 }
 for(const d of snapshot.users||[]){
  const u=data(d);if(!['patient','relative'].includes(u.role))continue;
  if(!patients.has(u.patientId))fail('users',d,'Mobile Patient reference missing');
  if(u.role==='relative'){
   if(!relatives.has(u.recipientId))fail('users',d,'Mobile Relative reference missing');
   if(u.accountStatus==='active'&&u.disabled!==true&&!(snapshot.patientRelativeLinks||[]).some(l=>{const v=data(l);return v.patientId===u.patientId&&v.relativeId===u.recipientId&&v.active===true;}))fail('users',d,'Mobile Relative lacks active Patient link');
  } else if(u.recipientId!==u.patientId)fail('users',d,'Patient account recipient mismatch');
  const binding=(snapshot.accountBindings||[]).find(b=>key(b)===u.role+'_'+u.recipientId);
  if(!binding||data(binding).uid!==key(d)||data(binding).patientId!==u.patientId)fail('users',d,'Account binding mismatch');
 }
 for(const d of snapshot.accountBindings||[]){
  const v=data(d);
  if(key(d)!==v.role+'_'+v.recipientId)fail('accountBindings',d,'Binding key mismatch');
  if(v.uid==null){
   if(!['notActivated','activationPending'].includes(v.accountStatus))fail('accountBindings',d,'Unbound account has unexpected activation status');
   if(v.accountStatus==='activationPending'){
    const invitation=(snapshot.invitations||[]).find(i=>key(i)===v.activationId),inv=data(invitation||{});
    if(!invitation||inv.role!==v.role||inv.recipientId!==v.recipientId||inv.patientId!==v.patientId||inv.usedBy||inv.revoked)fail('accountBindings',d,'Pending binding has no matching unconsumed invitation');
   }
   continue;
  }
  const u=(snapshot.users||[]).find(u=>key(u)===v.uid);
  if(!u||data(u).role!==v.role||data(u).recipientId!==v.recipientId||data(u).patientId!==v.patientId)fail('accountBindings',d,'Reverse account ownership mismatch');
 }
 const publicIds=(snapshot.patients||[]).map(d=>data(d).publicId);
 const duplicates=publicIds.length-new Set(publicIds).size;
 return {patientCount:patients.size,duplicates,missingIds:publicIds.filter(v=>!v).length,brokenReferences:issues.length,issues};
}
function requireIntegrity(snapshot){
 const report=inspectIntegrity(snapshot);
 if(report.duplicates||report.missingIds||report.brokenReferences)throw Error(`Migration stopped before writes: ${report.duplicates} duplicate IDs, ${report.missingIds} missing IDs, ${report.brokenReferences} unresolved references. Review the private integrity report; do not reactivate links automatically.`);
 return report;
}
module.exports={inspectIntegrity,requireIntegrity};
