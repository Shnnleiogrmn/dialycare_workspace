'use strict';
// Trusted workstation tool, never imported into Flutter or deployed as a function.
// Usage: node tools/link-spark-user.cjs UID staff
//        node tools/link-spark-user.cjs UID patient TEST-001
//        node tools/link-spark-user.cjs UID relative TEST-001 TEST-R001
// The account owner establishes the password; this tool never receives one.
const {connect}=require('../inspect-database-powershell.cjs');
const project='dialycare-backend-3f0ed';
const [uid,role,patientId,relativeId]=process.argv.slice(2);
const id=v=>typeof v==='string'&&/^[a-z0-9-]{2,100}$/i.test(v);
async function main(){
 if(!uid||!['staff','admin','patient','relative'].includes(role)||!['staff','admin'].includes(role)&&(!id(patientId)||role==='relative'&&!id(relativeId))) throw Error('Usage: link-spark-user.cjs UID staff|admin|patient|relative [PATIENT_ID] [RELATIVE_ID]');
 const request=await connect();
 const lookup=request(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts:lookup`,'POST',{localId:[uid]});
 const user=lookup.users?.[0];if(!user||user.disabled)throw Error('An enabled Firebase Auth account must exist first.');
 const root=`projects/${project}/databases/(default)/documents`;
 async function read(p){return request(`https://firestore.googleapis.com/v1/${root}/${p}`);}
 const recipientId=role==='patient'?patientId:relativeId;
 if(!['staff','admin'].includes(role)){
  const email=`${recipientId.toLowerCase()}@${role}.dialycare.invalid`;
  if(user.email?.toLowerCase()!==email && user.emailVerified!==true)throw Error('A verified real email or an explicitly controlled legacy role alias is required. Verify the person’s identity before linking.');
  await read(`patientProfiles/${patientId}`);
  if(role==='relative'){
   await read(`relatives/${relativeId}`);
   const link=await read(`patientRelativeLinks/${relativeId}_${patientId}`);
   if(link.fields?.active?.booleanValue!==true)throw Error('The designated-relative link must already be active.');
  }
 }
 const mobile=!['staff','admin'].includes(role);
 const values={role,disabled:false,accountStatus:'active',...(mobile?{patientId,recipientId,activationId:'trusted-administrator'}:{})};
 const fields=Object.fromEntries(Object.entries(values).map(([k,v])=>[k,typeof v==='boolean'?{booleanValue:v}:{stringValue:v}]));
 // Creation precondition prevents silently changing an existing account's access.
 const writes=[{update:{name:`${root}/users/${uid}`,fields},currentDocument:{exists:false},...(mobile?{updateTransforms:[{fieldPath:'activatedAt',setToServerValue:'REQUEST_TIME'}]}:{})}];
 if(mobile){
  const binding={...fields,uid:{stringValue:uid}};delete binding.disabled;
  writes.push({update:{name:`${root}/accountBindings/${role}_${recipientId}`,fields:binding},currentDocument:{exists:false},updateTransforms:[{fieldPath:'activatedAt',setToServerValue:'REQUEST_TIME'}]});
 }
 request(`https://firestore.googleapis.com/v1/${root}:commit`,'POST',{writes});
 console.log(JSON.stringify({project,linked:true,role,...(role==='staff'?{}:{patientId,recipientId})}));
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
