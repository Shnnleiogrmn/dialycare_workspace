"use strict";
// One-off minimal Patient-only avatar projection repair. No care records altered.
const {connect}=require('./inspect-database-powershell.cjs');
const {randomBytes}=require('node:crypto');
async function main(){
 const request=await connect(),root='projects/dialycare-backend-3f0ed/databases/(default)/documents',url='https://firestore.googleapis.com/v1/'+root;
 const rows=collection=>{const result=request(url+':runQuery','POST',{structuredQuery:{from:[{collectionId:collection}]}});return (Array.isArray(result)?result:[result]).filter(r=>r.document).map(r=>r.document);};
 const patients=rows('patients'),profiles=new Map(rows('patientAccountProfiles').map(d=>[d.name.split('/').pop(),d])),safe=new Map(rows('patientProfiles').map(d=>[d.name.split('/').pop(),d]));
 const writes=[];
 for(const patient of patients){
  const id=patient.name.split('/').pop(),profile=profiles.get(id),projection=safe.get(id),gender=patient.fields.gender?.stringValue||'';
  if(!profile||!projection||profile.fields.gender?.stringValue===gender)continue;
  writes.push({update:{name:profile.name,fields:{gender:{stringValue:gender}}},updateMask:{fieldPaths:['gender']},currentDocument:{updateTime:profile.updateTime}});
  writes.push({update:{name:projection.name,fields:{syncVersion:{stringValue:'avatar-'+randomBytes(16).toString('hex')}}},updateMask:{fieldPaths:['syncVersion']},currentDocument:{updateTime:projection.updateTime}});
 }
 console.log(JSON.stringify({patientRecordsRead:patients.length,patientOnlyProjectionsNeedingGender:writes.length/2,careRecordWrites:0}));
 if(process.argv[2]!=='--apply-existing-projections'){console.log('PREVIEW_ONLY_NO_WRITES');return;}
 if(writes.length){if(writes.length>450)throw Error('Review smaller migration batches.');request(url+':commit','POST',{writes});}
 console.log('EXISTING_PATIENT_ONLY_AVATAR_PROJECTIONS_UPDATED');
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
