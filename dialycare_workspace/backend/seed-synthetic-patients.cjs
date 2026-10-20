'use strict';
// Explicit trusted setup action. Never called by either app at startup.
const {connect}=require('./inspect-database-powershell.cjs');
const {dataset,seedKey}=require('./synthetic-dataset.cjs');
const project='dialycare-backend-3f0ed',root=`projects/${project}/databases/(default)/documents`,url='https://firestore.googleapis.com/v1/'+root;
function encode(v){if(v===null)return{nullValue:null};if(typeof v==='boolean')return{booleanValue:v};if(typeof v==='number')return Number.isInteger(v)?{integerValue:String(v)}:{doubleValue:v};if(Array.isArray(v))return{arrayValue:{values:v.map(encode)}};return{stringValue:String(v)};}
const doc=(p,data)=>({name:root+'/'+p,fields:Object.fromEntries(Object.entries(data).map(([k,v])=>[k,encode(v)]))});
const scalar=(d,k)=>d.fields?.[k]?.stringValue;
const id=(prefix,n)=>{if(n<1||n>999999)throw Error('ID range exhausted');return prefix+String(n).padStart(6,'0');};
async function main(){
 const apply=process.argv.includes('--apply'),r=await connect();
 function query(collection,fields){const rows=r(url+':runQuery','POST',{structuredQuery:{from:[{collectionId:collection}],select:{fields:fields.map(fieldPath=>({fieldPath}))}}});return(Array.isArray(rows)?rows:[rows]).filter(x=>x.document).map(x=>x.document);}
 const before=r(url+'/clinical/state');
 const patients=query('patients',['id','publicId','demonstrationSeed','scheduleGroup']),relatives=query('relatives',['id','publicId']);
 const sessions=query('sessions',['id','patientId','start']),links=query('patientRelativeLinks',['patientId','relativeId','relationship','active']);
 const reservations=query('publicIds',['role','internalId','publicId']);
 const records=dataset();
 if(records.length!==43||records.filter(x=>x.patient.scheduleGroup==='MWF').length!==22)throw Error('Invalid seed manifest');
 const existing=patients.filter(d=>scalar(d,'demonstrationSeed')===seedKey);
 if(existing.length){
  if(existing.length!==43)throw Error('Partial seed found; no automatic overwrite or repair performed.');
  for(const record of records){
   const p=patients.find(d=>scalar(d,'id')===record.patient.id),relative=relatives.find(d=>scalar(d,'id')===record.relative.id);
   if(!p||!relative||scalar(p,'scheduleGroup')!==record.patient.scheduleGroup)throw Error('Existing seed identity/group mismatch');
   const link=links.find(d=>scalar(d,'patientId')===record.patient.id&&scalar(d,'relativeId')===record.relative.id&&d.fields.active?.booleanValue===true);
   if(!link||scalar(link,'relationship')!==record.relationship)throw Error('Existing seed relationship mismatch');
   if(!reservations.some(d=>scalar(d,'publicId')===scalar(p,'publicId')&&scalar(d,'internalId')===record.patient.id)||!reservations.some(d=>scalar(d,'publicId')===scalar(relative,'publicId')&&scalar(d,'internalId')===record.relative.id))throw Error('Seed reservation mismatch');
  }
  console.log(JSON.stringify({result:'ALREADY_SEEDED_VERIFIED_NO_WRITES',MWF:22,TTHS:21,syntheticPatients:43,totalPatients:patients.length,relativeLinksVerified:43}));return;
 }
 for(const record of records)if(patients.some(d=>scalar(d,'id')===record.patient.id)||relatives.some(d=>scalar(d,'id')===record.relative.id))throw Error('Internal ID conflict; no changes made.');
 const counter=r(url+'/idCounters/center'),state=r(url+'/clinical/state');
 if(before.updateTime!==state.updateTime)throw Error('Workspace changed during seed inspection. Retry the preview.');
 const patientNext=Number(counter.fields.nextPatientNumber.integerValue),relativeNext=Number(counter.fields.nextRelativeNumber.integerValue);
 const occupiedDates=new Set(sessions.map(d=>scalar(d,'start')).filter(Boolean).map(s=>new Date(new Date(s).getTime()+8*3600000).toISOString().slice(0,10)));
 const now=new Date(Date.now()+8*3600000),anchorArg=process.argv.find(a=>a.startsWith('--anchor-date='))?.split('=')[1];
 if(anchorArg&&!/^\d{4}-\d{2}-\d{2}$/.test(anchorArg))throw Error('Anchor must be YYYY-MM-DD');
 const anchor=anchorArg?new Date(anchorArg+'T00:00:00Z'):new Date(Date.UTC(now.getUTCFullYear(),now.getUTCMonth(),now.getUTCDate()+1));
 if(Number.isNaN(anchor.getTime()))throw Error('Invalid anchor date');
 function scheduledAt(group,index){let d=new Date(anchor),eligible=0;for(let safety=0;safety<370;safety++,d.setUTCDate(d.getUTCDate()+1)){
  const weekday=d.getUTCDay(),valid=(group==='MWF'?[1,3,5]:[2,4,6]).includes(weekday);
  if(valid&&!occupiedDates.has(d.toISOString().slice(0,10))){if(eligible++===Math.floor(index/18)){const hour=[6,12,18][Math.floor((index%18)/6)];return new Date(d.getTime()+(hour-8)*3600000).toISOString();}}
 }throw Error('No safe demonstration date found');}
 const writes=[],plan=[];
 const create=(p,data,transforms=[])=>writes.push({update:doc(p,data),currentDocument:{exists:false},...(transforms.length?{updateTransforms:transforms.map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}))}:{})});
 for(let i=0;i<records.length;i++){
  const row=records[i],p={...row.patient,publicId:id('DC-',patientNext+i)},relative={...row.relative,publicId:id('R-',relativeNext+i)};
  if(reservations.some(d=>scalar(d,'publicId')===p.publicId||scalar(d,'publicId')===relative.publicId))throw Error('Public ID conflict; no changes made.');
  if(patients.some(d=>scalar(d,'publicId')===p.publicId)||relatives.some(d=>scalar(d,'publicId')===relative.publicId))throw Error('Existing record public ID conflict; no changes made.');
  create('patients/'+p.id,p,['createdAt','updatedAt']);
  create('relatives/'+relative.id,relative);
  create('patientRelativeLinks/'+relative.id+'_'+p.id,{relativeId:relative.id,patientId:p.id,relationship:row.relationship,active:true});
  create('patientProfiles/'+p.id,{id:p.id,name:p.name,publicId:p.publicId,scheduleGroup:p.scheduleGroup,syncVersion:seedKey});
  create('patientAccountProfiles/'+p.id,{id:p.id,contact:p.contact,relativeName:relative.name,relationship:row.relationship});
  create('publicIds/'+p.publicId,{role:'patient',internalId:p.id,publicId:p.publicId});
  create('publicIds/'+relative.publicId,{role:'relative',internalId:relative.id,publicId:relative.publicId});
  const sid='demo-mwf-tths-v1-s'+String(i+1).padStart(2,'0'),start=scheduledAt(p.scheduleGroup,row.groupIndex);
  create('sessions/'+sid,{id:sid,patientId:p.id,start,room:p.room,batch:p.batch,status:'Pending',revision:0,progress:0,expectedEnd:null,scheduleGroup:p.scheduleGroup,plannedDurationMinutes:row.plannedDurationMinutes});
  plan.push({patientId:p.publicId,relativeId:relative.publicId,group:p.scheduleGroup,room:p.room,batch:p.batch,start,plannedDurationMinutes:row.plannedDurationMinutes});
 }
 writes.push({update:doc('idCounters/center',{nextPatientNumber:patientNext+43,nextRelativeNumber:relativeNext+43}),currentDocument:{updateTime:counter.updateTime}});
 writes.push({update:doc('clinical/state',{revision:Date.now()*1000,nextPatientNumber:patientNext+43,nextRelativeNumber:relativeNext+43}),updateMask:{fieldPaths:['revision','nextPatientNumber','nextRelativeNumber']},currentDocument:{updateTime:state.updateTime}});
 create('auditEvents/'+seedKey,{actorUid:'trusted-explicit-seed-tool',actorRole:'admin',action:'syntheticDatasetCreated',resourceType:'demonstrationDataset',resourceId:seedKey,outcome:'success'},['timestamp']);
 if(writes.length>450)throw Error('Seed exceeds reviewed atomic write bound');
 console.log(JSON.stringify({mode:apply?'apply':'preview',syntheticPatients:43,MWF:22,TTHS:21,existingPatientsPreserved:patients.length,totalAfter:patients.length+43,writes:writes.length,plan},null,2));
 if(!apply){console.log('PREVIEW_ONLY_NO_WRITES');return;}
 r(url+':commit','POST',{writes});
 console.log('SYNTHETIC_DATASET_APPLIED_ATOMICALLY. Run again without --apply to verify idempotency and links.');
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
