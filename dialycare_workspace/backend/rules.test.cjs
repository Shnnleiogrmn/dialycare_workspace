'use strict';
const {test,before,after}=require('node:test');
const {readFileSync}=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc,deleteDoc,getDocs,collection,query,where,serverTimestamp,writeBatch,runTransaction}=require('firebase/firestore');
let env;
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-dialycare-spark',firestore:{host:'127.0.0.1',port:8089,rules:readFileSync('firestore.spark.rules','utf8')}});
 await env.withSecurityRulesDisabled(async c=>{
  const db=c.firestore();
  for(const [id,data] of Object.entries({staff:{role:'staff',disabled:false,accountStatus:'active'},patient:{role:'patient',disabled:false,patientId:'TEST-001',recipientId:'TEST-001'},relative:{role:'relative',disabled:false,patientId:'TEST-001',recipientId:'TEST-R001'},other:{role:'patient',disabled:false,patientId:'TEST-002',recipientId:'TEST-002'},disabled:{role:'patient',disabled:true,patientId:'TEST-001',recipientId:'TEST-001'}})) await setDoc(doc(db,'users',id),data);
  for(const id of ['TEST-001','TEST-002']) {await setDoc(doc(db,'patients',id),{id,name:'Fictional Patient',medicalNotes:'private'});await setDoc(doc(db,'patientProfiles',id),{id,name:'Fictional Patient'});await setDoc(doc(db,'sessions','S-'+id),{id:'S-'+id,patientId:id,start:'2026-11-01T00:00:00Z',room:'Test Room 01',batch:'Batch A',status:'Pending'});}
  await setDoc(doc(db,'relatives/TEST-R001'),{id:'TEST-R001',name:'Test Relative'});
  await setDoc(doc(db,'patientRelativeLinks/TEST-R001_TEST-001'),{relativeId:'TEST-R001',patientId:'TEST-001',active:true,relationship:'Other'});
  for(const role of ['patient','relative']) await setDoc(doc(db,'notifications','N-'+role),{id:'N-'+role,patientId:'TEST-001',recipientId:role==='patient'?'TEST-001':'TEST-R001',recipientType:role,recipientKey:role+':'+(role==='patient'?'TEST-001':'TEST-R001')+':TEST-001',title:'Test',message:'Fictional reminder',readAt:null});
 });
});
after(async()=>{await env?.cleanup();});
const db=id=>id?env.authenticatedContext(id).firestore():env.unauthenticatedContext().firestore();

test('unmatched documents remain default-denied for every role',async()=>{
 for(const who of ['staff','patient','relative','unknown',null]){
  const ref=doc(db(who),'unmatchedValidation/denied');
  await assertFails(getDoc(ref));
  await assertFails(setDoc(ref,{value:'synthetic authorization fixture'}));
 }
});

async function transition(ref, patch, options={}) {
 const old=(await getDoc(ref)).data(), revision=(old.revision||0)+1;
 const d=ref.firestore, batch=options.batch||writeBatch(d), to=patch.status;
 const type=to==='In Progress'?(old.status==='Paused'?'RESUME':'START'):to==='Paused'?'PAUSE':to==='Completed'?'COMPLETE':to==='Ended Early'?'END_EARLY':to==='Cancelled'?'CANCEL':'STATUS';
 batch.update(ref,{...patch,revision});
 const id=old.id+'_'+revision;
 batch.set(doc(d,'sessionEvents/'+id),{id,sessionId:old.id,patientId:old.patientId,revision,fromStatus:old.status,toStatus:to,type,actorUid:'staff',reasonCode:options.reason||'',note:options.note||'',timestamp:serverTimestamp()});
 return options.batch ? batch : batch.commit();
}
test('session clock is server-stamped, stable, Staff-controlled and never completed by time alone',async()=>{
 const d=db('staff'),ref=doc(d,'sessions/TIMER-SECURITY');
 await assertSucceeds(setDoc(ref,{id:'TIMER-SECURITY',patientId:'TEST-002',start:'2026-11-02T00:00:00Z',room:'Test Room',batch:'Batch A',status:'Pending',plannedDurationMinutes:180,scheduleGroup:'MWF'}));
 for(const who of ['patient','relative',null]) await assertFails(updateDoc(doc(db(who),'sessions/TIMER-SECURITY'),{plannedDurationMinutes:300}));
 await assertFails(updateDoc(ref,{plannedDurationMinutes:0}));
 await assertFails(updateDoc(ref,{plannedDurationMinutes:721}));
 await assertFails(updateDoc(ref,{status:'Completed',completedAt:serverTimestamp()}));
 await assertFails(updateDoc(ref,{status:'Ready for Pick Up'}));
 await assertFails(updateDoc(ref,{status:'In Progress',actualStartedAt:new Date('2020-01-01')}));
 await assertSucceeds(transition(ref,{status:'In Progress',actualStartedAt:serverTimestamp()}));
 const started=(await getDoc(ref)).data().actualStartedAt;
 await assertFails(updateDoc(ref,{actualStartedAt:serverTimestamp()}));
 await assertFails(updateDoc(ref,{plannedDurationMinutes:240}));
 await assertFails(updateDoc(ref,{status:'Pending'}));
 await assertFails(updateDoc(ref,{status:'Completed',completedAt:new Date('2020-01-01')}));
 await assertSucceeds(transition(ref,{status:'Completed',completedAt:serverTimestamp()}));
 await assertFails(updateDoc(ref,{completedAt:serverTimestamp()}));
 await assertFails(updateDoc(ref,{status:'In Progress'}));
 await assertSucceeds(transition(ref,{status:'Ready for Pick Up'}));
 const finished=(await getDoc(ref)).data();
 if(!finished.actualStartedAt.isEqual(started))throw Error('Start was reset');
 for(const who of ['patient','relative',null]) await assertFails(getDoc(doc(db(who),'sessions/TIMER-SECURITY')));
});

test('Staff/Admin require explicit active account status; legacy flag alone cannot grant access',async()=>{
 for(const [id,mapping,allowed] of [
  ['approved-admin',{role:'admin',disabled:false,accountStatus:'active'},true],
  ['inactive-staff',{role:'staff',disabled:false,accountStatus:'disabled'},false],
  ['missing-status',{role:'staff',disabled:false},false],
  ['disabled-staff',{role:'staff',disabled:true,accountStatus:'active'},false],
 ]){
  await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'users',id),mapping));
  const read=getDoc(doc(db(id),'patients/TEST-001'));
  await (allowed?assertSucceeds(read):assertFails(read));
  if(!allowed) await assertFails(setDoc(doc(db(id),'patients/STATUS-FORGE'),{id:'STATUS-FORGE',name:'Test'}));
 }
 await assertFails(updateDoc(doc(db('inactive-staff'),'users/inactive-staff'),{accountStatus:'active'}));
});
test('staff can read operational records; anonymous and unlinked users cannot',async()=>{
 await assertSucceeds(getDoc(doc(db('staff'),'patients/TEST-001')));
 for(const id of [null,'unknown','disabled']) await assertFails(getDoc(doc(db(id),'patientProfiles/TEST-001')));
});
test('patient gets own safe profile and filtered sessions, never unrelated or full clinical records',async()=>{
 const d=db('patient');await assertSucceeds(getDoc(doc(d,'patientProfiles/TEST-001')));
 await assertFails(getDoc(doc(d,'patientProfiles/TEST-002')));await assertFails(getDoc(doc(d,'patients/TEST-001')));
 await assertSucceeds(getDocs(query(collection(d,'sessions'),where('patientId','==','TEST-001'))));
 await assertFails(getDocs(collection(d,'sessions')));await assertFails(getDocs(query(collection(d,'sessions'),where('patientId','==','TEST-002'))));
});
test('relative gets only linked coordination data, own relative record and filtered sessions',async()=>{
 const d=db('relative');await assertSucceeds(getDoc(doc(d,'patientProfiles/TEST-001')));await assertSucceeds(getDoc(doc(d,'relatives/TEST-R001')));
 await assertFails(getDoc(doc(d,'patientProfiles/TEST-002')));await assertFails(getDoc(doc(d,'patients/TEST-001')));
 await assertSucceeds(getDocs(query(collection(d,'sessions'),where('patientId','==','TEST-001'))));
 await assertFails(getDocs(collection(d,'patients')));
});
test('clients including staff cannot self-provision roles or arbitrary user links',async()=>{
 for(const role of ['patient','relative','staff']) await assertFails(updateDoc(doc(db(role),'users',role),{role:'staff',patientId:'TEST-002'}));
 await assertFails(setDoc(doc(db('relative'),'patientRelativeLinks/TEST-R001_TEST-002'),{relativeId:'TEST-R001',patientId:'TEST-002',active:true}));
});
test('notification query is recipient scoped; only readAt can be changed by recipient',async()=>{
 const d=db('patient');await assertSucceeds(getDocs(query(collection(d,'notifications'),where('recipientKey','==','patient:TEST-001:TEST-001'))));
 await assertFails(getDocs(collection(d,'notifications')));await assertFails(getDoc(doc(d,'notifications/N-relative')));
 await assertSucceeds(updateDoc(doc(d,'notifications/N-patient'),{readAt:serverTimestamp()}));
 await assertFails(updateDoc(doc(d,'notifications/N-patient'),{title:'Forged'}));
 await assertFails(updateDoc(doc(d,'notifications/N-relative'),{readAt:serverTimestamp()}));
});
test('staff saves session transition and pickup history in one batch with server time',async()=>{
 await assertSucceeds(transition(doc(db('staff'),'sessions/S-TEST-001'),{status:'In Progress',plannedDurationMinutes:240,actualStartedAt:serverTimestamp()}));
 await assertSucceeds(transition(doc(db('staff'),'sessions/S-TEST-001'),{status:'Completed',completedAt:serverTimestamp()}));
 const d=db('staff'),batch=writeBatch(d);
 await transition(doc(d,'sessions/S-TEST-001'),{status:'Ready for Pick Up'},{batch});
 batch.set(doc(d,'notifications/PICKUP'),{id:'PICKUP',patientId:'TEST-001',recipientId:'TEST-R001',recipientType:'relative',recipientKey:'relative:TEST-R001:TEST-001',title:'Ready for Pick Up',message:'Fictional patient is ready',createdAt:serverTimestamp(),readAt:null});
 await assertSucceeds(batch.commit());
 await assertSucceeds(getDoc(doc(db('relative'),'notifications/PICKUP')));
});
test('safe projections cannot contain clinical fields and sessions reject unknown statuses',async()=>{
 await assertFails(setDoc(doc(db('staff'),'patientProfiles/TEST-003'),{id:'TEST-003',name:'Test',medicalNotes:'private'}));
 await assertFails(updateDoc(doc(db('staff'),'sessions/S-TEST-001'),{status:'Invented'}));
});
test('sync markers are Staff-only nonclinical strings and cannot carry sensitive fields',async()=>{
 await assertSucceeds(updateDoc(doc(db('staff'),'patientProfiles/TEST-001'),{syncVersion:'0123456789abcdef'}));
 for(const who of ['patient','relative',null]) await assertFails(updateDoc(doc(db(who),'patientProfiles/TEST-001'),{syncVersion:'forged'}));
 await assertFails(updateDoc(doc(db('staff'),'patientProfiles/TEST-001'),{syncVersion:{private:'value'}}));
 await assertFails(updateDoc(doc(db('staff'),'patientProfiles/TEST-001'),{syncVersion:'x'.repeat(81)}));
 for(const field of ['philHealthNumber','mdrStatus','medicalNotes']) await assertFails(updateDoc(doc(db('staff'),'patientProfiles/TEST-001'),{[field]:'private'}));
});

test('Patient account projection is private to the Patient and contains no medical fields',async()=>{
 const d=db('staff');await assertSucceeds(setDoc(doc(d,'patientAccountProfiles/TEST-001'),{id:'TEST-001',contact:'0000000000',relativeName:'Approved relative',relationship:'Other'}));
 await assertSucceeds(getDoc(doc(db('patient'),'patientAccountProfiles/TEST-001')));
 for(const who of ['relative','other',null])await assertFails(getDoc(doc(db(who),'patientAccountProfiles/TEST-001')));
 await assertFails(updateDoc(doc(db('patient'),'patientAccountProfiles/TEST-001'),{contact:'forged'}));
 for(const field of ['philHealthNumber','mdrStatus','medicalNotes'])await assertFails(updateDoc(doc(d,'patientAccountProfiles/TEST-001'),{[field]:'private'}));
});

test('removing a designated link revokes relative reads',async()=>{
 await assertSucceeds(updateDoc(doc(db('staff'),'patientRelativeLinks/TEST-R001_TEST-001'),{active:false}));
 await assertFails(getDoc(doc(db('relative'),'patientProfiles/TEST-001')));
 await assertFails(getDocs(query(collection(db('relative'),'sessions'),where('patientId','==','TEST-001'))));
});



test('audit events are append-only, actor-bound and unreadable to Mobile or anonymous users',async()=>{
 const d=db('staff'),event={actorUid:'staff',actorRole:'staff',action:'patientUpdated',resourceType:'patient',resourceId:'TEST-001',outcome:'success',timestamp:serverTimestamp()};
 await assertSucceeds(setDoc(doc(d,'auditEvents/GV-EVENT'),event));
 await assertSucceeds(getDocs(collection(d,'auditEvents')));
 for(const who of ['patient','relative',null]) await assertFails(getDoc(doc(db(who),'auditEvents/GV-EVENT')));
 await assertFails(updateDoc(doc(d,'auditEvents/GV-EVENT'),{action:'patientCreated'}));
 const {deleteDoc}=require('firebase/firestore');await assertFails(deleteDoc(doc(d,'auditEvents/GV-EVENT')));
 for(const [id,extra] of Object.entries({actor:{actorUid:'someone-else'},role:{actorRole:'admin'},secret:{pin:'do-not-log'},time:{timestamp:'client-time'}})) await assertFails(setDoc(doc(d,'auditEvents/GV-'+id),{...event,...extra}));
 await assertFails(setDoc(doc(db('patient'),'auditEvents/GV-MOBILE'),{...event,actorUid:'patient',actorRole:'patient'}));
});

test('center information is readable by Staff but writable only by approved Center Admin',async()=>{
 await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'users/GV-ADMIN'),{role:'admin',disabled:false,accountStatus:'active'}));
 const value={name:'Fictional Development Center',contact:'',address:'',updatedBy:'GV-ADMIN',updatedAt:serverTimestamp()};
 await assertFails(setDoc(doc(db('staff'),'settings/center'),{...value,updatedBy:'staff'}));
 await assertSucceeds(setDoc(doc(db('GV-ADMIN'),'settings/center'),value));
 await assertSucceeds(getDoc(doc(db('staff'),'settings/center')));
 for(const who of ['patient','relative',null]) await assertFails(getDoc(doc(db(who),'settings/center')));
 await assertFails(updateDoc(doc(db('GV-ADMIN'),'settings/center'),{secret:'not-allowed',updatedAt:serverTimestamp()}));
});

test('archive preserves history, blocks new sessions and permanent deletion, and restores same Patient',async()=>{
 const d=db('staff'),{deleteDoc}=require('firebase/firestore');
 await assertFails(updateDoc(doc(d,'patients/TEST-001'),{recordStatus:'archived',archivedAt:'client-time',archivedBy:'staff'}));
 const simultaneous=writeBatch(d);simultaneous.update(doc(d,'patients/TEST-001'),{recordStatus:'archived',archivedAt:serverTimestamp(),archivedBy:'staff'});simultaneous.set(doc(d,'sessions/GV-SAME-BATCH'),{id:'GV-SAME-BATCH',patientId:'TEST-001',start:'2026-12-01T00:00:00Z',room:'Test',batch:'Batch A',status:'Pending'});await assertFails(simultaneous.commit());
 await assertSucceeds(updateDoc(doc(d,'patients/TEST-001'),{recordStatus:'archived',archivedAt:serverTimestamp(),archivedBy:'staff'}));
 await assertSucceeds(getDoc(doc(d,'sessions/S-TEST-001')));
 await assertFails(setDoc(doc(d,'sessions/GV-NEW'),{id:'GV-NEW',patientId:'TEST-001',start:'2026-12-01T00:00:00Z',room:'Test',batch:'Batch A',status:'Pending'}));
 await assertFails(setDoc(doc(d,'notifications/GV-ARCHIVED'),{id:'GV-ARCHIVED',patientId:'TEST-001',recipientId:'TEST-001',recipientType:'patient',recipientKey:'patient:TEST-001:TEST-001',createdAt:serverTimestamp(),readAt:null}));
 await assertFails(deleteDoc(doc(d,'patients/TEST-001')));await assertFails(deleteDoc(doc(d,'patientProfiles/TEST-001')));
 await assertSucceeds(updateDoc(doc(d,'patients/TEST-001'),{recordStatus:'active',archivedAt:null,archivedBy:null}));
 await assertSucceeds(setDoc(doc(d,'sessions/GV-NEW'),{id:'GV-NEW',patientId:'TEST-001',start:'2026-12-01T00:00:00Z',room:'Test',batch:'Batch A',status:'Pending'}));
});

test('public ID reservations are immutable, unique and inaccessible to Mobile; counters cannot decrease',async()=>{
 const d=db('staff'),batch=writeBatch(d);
 // Existing legacy records remain editable, but new legacy IDs are forbidden.
 await env.withSecurityRulesDisabled(async c=>{
  await setDoc(doc(c.firestore(),'publicIds/DC-000100'),{role:'patient',internalId:'PUBLIC-ID-TEST',publicId:'DC-000100'});
  await setDoc(doc(c.firestore(),'patients/PUBLIC-ID-TEST'),{id:'PUBLIC-ID-TEST',publicId:'DC-000100',name:'Identity verification',recordStatus:'active'});
 });
 await assertSucceeds(updateDoc(doc(d,'patients/PUBLIC-ID-TEST'),{name:'Updated legacy record'}));
 await assertFails(setDoc(doc(d,'publicIds/DC-000101'),{role:'patient',internalId:'LEGACY-NEW',publicId:'DC-000101'}));
 await assertFails(setDoc(doc(d,'patients/LEGACY-NEW'),{id:'LEGACY-NEW',publicId:'DC-000101',name:'Legacy creation denied'}));
 batch.set(doc(d,'publicIds/R-000100'),{role:'relative',internalId:'PUBLIC-R-ID-TEST',publicId:'R-000100'});
 batch.set(doc(d,'relatives/PUBLIC-R-ID-TEST'),{id:'PUBLIC-R-ID-TEST',publicId:'R-000100',name:'Identity verification',contact:'',address:''});
 batch.set(doc(d,'idCounters/center'),{nextPatientNumber:101,nextRelativeNumber:101});
 await assertSucceeds(batch.commit());
 await assertFails(setDoc(doc(d,'patients/ANOTHER-PERSON'),{id:'ANOTHER-PERSON',publicId:'DC-000100',name:'Cannot reuse'}));
 await assertFails(updateDoc(doc(d,'patients/PUBLIC-ID-TEST'),{publicId:'DC-000101'}));
 await assertFails(updateDoc(doc(d,'relatives/PUBLIC-R-ID-TEST'),{publicId:'R-000101'}));
 for(const field of ['philHealthNumber','mdrStatus','medicalNotes'])await assertFails(updateDoc(doc(d,'relatives/PUBLIC-R-ID-TEST'),{[field]:'private'}));
 const {deleteDoc}=require('firebase/firestore');
 await assertFails(deleteDoc(doc(d,'publicIds/DC-000100')));
 await assertFails(updateDoc(doc(d,'publicIds/DC-000100'),{internalId:'ANOTHER-PERSON'}));
 await assertFails(updateDoc(doc(d,'idCounters/center'),{nextPatientNumber:1}));
 await assertFails(deleteDoc(doc(d,'idCounters/center')));
 for(const who of ['patient','relative',null]){
  await assertFails(getDoc(doc(db(who),'publicIds/DC-000100')));
  await assertFails(getDoc(doc(db(who),'idCounters/center')));
 }
});

test('pause/resume/end events are atomic, server-timed, immutable and Staff-private',async()=>{
 const d=db('staff'), ref=doc(d,'sessions/INTERRUPTION');
 await assertSucceeds(setDoc(ref,{id:'INTERRUPTION',patientId:'TEST-002',start:'2026-11-03T00:00:00Z',room:'Test',batch:'Batch A',status:'Pending',revision:0,plannedDurationMinutes:240}));
 await assertFails(transition(ref,{status:'Paused',pauseSequence:1,pauseIntervals:{p1:{pausedAt:serverTimestamp()}}},{reason:'equipment'}));
 await assertSucceeds(transition(ref,{status:'In Progress',actualStartedAt:serverTimestamp()}));
 await assertFails(updateDoc(ref,{status:'Paused',revision:2,pauseSequence:1,pauseIntervals:{p1:{pausedAt:serverTimestamp()}}}));
 await assertFails(transition(ref,{status:'Paused',pauseSequence:1,pauseIntervals:{p1:{pausedAt:serverTimestamp()}}}));
 await assertSucceeds(transition(ref,{status:'Paused',pauseSequence:1,pauseIntervals:{p1:{pausedAt:serverTimestamp()}}},{reason:'equipment',note:'INTERNAL PRIVATE TEST'}));
 const paused=(await getDoc(ref)).data();
 await assertFails(transition(ref,{status:'Completed',completedAt:serverTimestamp()}));
 await assertSucceeds(transition(ref,{status:'In Progress','pauseIntervals.p1.resumedAt':serverTimestamp()}));
 await assertSucceeds(transition(ref,{status:'Paused',pauseSequence:2,'pauseIntervals.p2':{pausedAt:serverTimestamp()}},{reason:'temporary'}));
 await assertSucceeds(transition(ref,{status:'Ended Early',endedAt:serverTimestamp(),'pauseIntervals.p2.resumedAt':serverTimestamp()},{reason:'clinicalDecision'}));
 await assertFails(transition(ref,{status:'In Progress'}));
 await assertFails(updateDoc(ref,{'pauseIntervals.p1.pausedAt':serverTimestamp(),revision:7}));
 for(const who of ['patient','relative','other',null]) {
   await assertFails(getDoc(doc(db(who),'sessionEvents/INTERRUPTION_2')));
   await assertFails(getDocs(query(collection(db(who),'sessionEvents'),where('sessionId','==','INTERRUPTION'))));
   await assertFails(updateDoc(doc(db(who),'sessions/INTERRUPTION'),{status:'In Progress'}));
 }
 await assertFails(updateDoc(doc(d,'sessionEvents/INTERRUPTION_2'),{note:'forged'}));
 await assertFails(updateDoc(ref,{note:'private'}));
 if(!paused.pauseIntervals.p1.pausedAt) throw Error('Pause missing');
});

test('batch configuration is Center Admin-only and capacity is optional',async()=>{
 await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'users/batch-admin'),{role:'admin',disabled:false,accountStatus:'active'}));
 const data={id:'CONFIG-A',name:'Batch A',startMinute:480,endMinute:720,capacity:null,active:true};
 await assertSucceeds(setDoc(doc(db('batch-admin'),'batches/CONFIG-A'),data));
 await assertSucceeds(getDoc(doc(db('staff'),'batches/CONFIG-A')));
 for(const who of ['staff','patient','relative',null]) await assertFails(setDoc(doc(db(who),'batches/CONFIG-A'),{...data,capacity:10}));
 await assertFails(updateDoc(doc(db('batch-admin'),'batches/CONFIG-A'),{capacity:0}));
});

test('yearly Patient IDs allocate atomically, reject reuse, and keep Relative IDs unchanged', async()=>{
 const d=db('staff'), year=new Date().getFullYear(), counter=doc(d,`idCounters/patients-${year}`);
 const initial=await getDoc(counter), first=initial.exists()?initial.data().nextPatientNumber:1;
 async function allocate(internalId){
  return runTransaction(d,async tx=>{
   const snap=await tx.get(counter), sequence=snap.exists()?snap.data().nextPatientNumber:1;
   const publicId=`DP-${year}-${String(sequence).padStart(3,'0')}`;
   tx.set(counter,{year,nextPatientNumber:sequence+1});
   tx.set(doc(d,'publicIds/'+publicId),{role:'patient',internalId,publicId,year,sequence});
   tx.set(doc(d,'patients/'+internalId),{id:internalId,publicId,name:'Synthetic concurrency fixture',recordStatus:'active'});
   return publicId;
  });
 }
 const owners=['YEAR-RACE-A','YEAR-RACE-B'];
 const outcomes=await Promise.allSettled(owners.map(allocate));
 if(!outcomes.some(r=>r.status==='fulfilled'))throw Error('No concurrent allocation succeeded.');
 const ids=[];
 for(let i=0;i<outcomes.length;i++){
  const result=outcomes[i];
  if(result.status==='fulfilled'){ids.push(result.value);continue;}
  // Rules can reject a stale sequence before the SDK sees an ABORTED conflict.
  // Retry only this proven race, after a fresh read; other denials must fail.
  if(!['permission-denied','aborted'].includes(result.reason.code))throw result.reason;
  if((await getDoc(counter)).data().nextPatientNumber<=first)throw result.reason;
  ids.push(await allocate(owners[i]));
 }
 if(new Set(ids).size!==2)throw Error('Duplicate Patient IDs');
 const next=(await getDoc(counter)).data().nextPatientNumber;
 if(next!==first+2)throw Error('Unexpected yearly counter');
 await assertFails(setDoc(doc(d,'patients/YEAR-REUSE'),{id:'YEAR-REUSE',publicId:ids[0],recordStatus:'active'}));
 await assertFails(updateDoc(doc(d,'patients/YEAR-RACE-A'),{publicId:`DP-${year}-9999`}));
 await assertFails(updateDoc(counter,{nextPatientNumber:1}));
 await assertFails(deleteDoc(doc(d,'publicIds/'+ids[0])));
 for(const who of ['patient','relative',null])await assertFails(getDoc(doc(db(who),`idCounters/patients-${year}`)));
 const batch=writeBatch(d), invalid=`DP-${year}-000`;
 batch.set(doc(d,'publicIds/'+invalid),{role:'patient',internalId:'INVALID-YEAR',publicId:invalid,year,sequence:0});
 batch.set(doc(d,'patients/INVALID-YEAR'),{id:'INVALID-YEAR',publicId:invalid});
 await assertFails(batch.commit());
});
