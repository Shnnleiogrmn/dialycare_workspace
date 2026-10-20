"use strict";
const {connect}=require('./inspect-database-powershell.cjs');const {dataset,seedKey}=require('./synthetic-dataset.cjs');
(async()=>{
 const r=await connect(),url='https://firestore.googleapis.com/v1/projects/dialycare-backend-3f0ed/databases/(default)/documents';
 const value=v=>v.stringValue??(v.integerValue===undefined?undefined:Number(v.integerValue))??v.booleanValue??null;
 const rows=c=>{const rs=r(url+':runQuery','POST',{structuredQuery:{from:[{collectionId:c}]}});return(Array.isArray(rs)?rs:[rs]).filter(x=>x.document).map(x=>Object.fromEntries(Object.entries(x.document.fields||{}).map(([k,v])=>[k,value(v)])));};
 const patients=rows('patients'),relatives=rows('relatives'),links=rows('patientRelativeLinks'),bindings=rows('accountBindings');
 const active=links.filter(l=>l.active),retired=links.filter(l=>!l.active),duplicateGroups=new Map();
 for(const relative of relatives){const key=JSON.stringify([relative.name,relative.contact,relative.address]);duplicateGroups.set(key,(duplicateGroups.get(key)||0)+1);}
 const summary={patients:patients.length,relativeIdentities:relatives.length,activeLinks:active.length,inactiveLinks:retired.length,unlinkedRelativeIdentities:relatives.filter(x=>!active.some(l=>l.relativeId===x.id)).length,identicalRelativeIdentityGroups:[...duplicateGroups.values()].filter(n=>n>1).length,patientsWithMultipleActiveRelatives:patients.filter(p=>active.filter(l=>l.patientId===p.id).length>1).length,activeBindingsWithoutActiveLink:bindings.filter(b=>b.role==='relative'&&b.accountStatus==='active'&&!active.some(l=>l.relativeId===b.recipientId&&l.patientId===b.patientId)).length};
 const mismatches=[];
 for(const expected of dataset()){
  const p=patients.find(p=>p.id===expected.patient.id);if(!p)continue;
  const current=active.filter(l=>l.patientId===p.id),original=links.find(l=>l.patientId===p.id&&l.relativeId===expected.relative.id);
  for(const l of current){const relative=relatives.find(r=>r.id===l.relativeId);if(l.relativeId!==expected.relative.id||l.relationship!==expected.relationship)mismatches.push({patientPublicId:p.publicId,activeRelativePublicId:relative?.publicId,originalLinkActive:original?.active??null,originalIdentityRetained:relatives.some(r=>r.id===expected.relative.id),sameExpectedName:relative?.name===expected.relative.name,sameExpectedContact:relative?.contact===expected.relative.contact,relationshipMatches:l.relationship===expected.relationship});}
 }
 console.log(JSON.stringify({summary,syntheticLinkDifferences:mismatches}));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
