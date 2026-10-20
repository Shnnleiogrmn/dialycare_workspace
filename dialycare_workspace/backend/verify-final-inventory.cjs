'use strict';
// Read only: inspect identifiers/counts, never clinical contents or credentials.
const {connect}=require('./inspect-database-powershell.cjs');
(async()=>{
 const r=await connect(),root='https://firestore.googleapis.com/v1/projects/dialycare-backend-3f0ed/databases/(default)/documents';
 for(const collection of ['patients','relatives','users','sessions','patientAccountProfiles','sessionEvents','batches']){
  const rows=r(root+':runQuery','POST',{structuredQuery:{from:[{collectionId:collection}],select:{fields:[{fieldPath:'__name__'},{fieldPath:'patientId'},{fieldPath:'recipientId'}]}}});
  const documents=(Array.isArray(rows)?rows:[rows]).filter(x=>x.document).map(x=>x.document);
  const ids=documents.map(d=>d.name.split('/').pop());
  if(ids.some(id=>id.includes('DIAG-')))throw Error('A disposable care fixture remains in '+collection);
  if(documents.some(d=>Object.values(d.fields||{}).some(v=>v.stringValue?.includes('DIAG-'))))throw Error('A disposable linked fixture remains in '+collection);
  console.log(JSON.stringify({collection,count:ids.length}));
 }
 const counters=r(root+'/idCounters/center');
 console.log(JSON.stringify({nextPatientNumber:counters.fields.nextPatientNumber.integerValue,nextRelativeNumber:counters.fields.nextRelativeNumber.integerValue}));
 const state=r(root+'/clinical/state');
 for(const field of ['notificationEvents','notifications']){
  const values=state.fields[field]?.arrayValue?.values||[];
  if(values.some(v=>JSON.stringify(v).includes('DIAG-')))throw Error('Final fixture metadata remains in '+field);
 }
 console.log('FINAL_LIVE_INVENTORY_VERIFIED');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
