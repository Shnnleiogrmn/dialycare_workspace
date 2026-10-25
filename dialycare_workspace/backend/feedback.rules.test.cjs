'use strict';
const {test,before,beforeEach,after}=require('node:test');
const {readFileSync}=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc,deleteDoc,getDocs,collection,query,where,serverTimestamp,writeBatch}=require('firebase/firestore');
let env,sequence=0;
const users={
 staff:{role:'staff',disabled:false,accountStatus:'active'},
 patient:{role:'patient',patientId:'P1',recipientId:'P1',disabled:false,accountStatus:'active',activationId:'fixture'},
 other:{role:'patient',patientId:'P2',recipientId:'P2',disabled:false,accountStatus:'active',activationId:'fixture'},
 relative:{role:'relative',patientId:'P1',recipientId:'R1',disabled:false,accountStatus:'active',activationId:'fixture'},
 otherRelative:{role:'relative',patientId:'P1',recipientId:'R2',disabled:false,accountStatus:'active',activationId:'fixture'},
 unlinked:{role:'relative',patientId:'P1',recipientId:'R3',disabled:false,accountStatus:'active',activationId:'fixture'},
};
const db=uid=>uid?env.authenticatedContext(uid).firestore():env.unauthenticatedContext().firestore();
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-dialycare-feedback',firestore:{host:'127.0.0.1',port:8089,rules:readFileSync('firestore.spark.rules','utf8')}});});
beforeEach(async()=>{
 await env.clearFirestore();
 await env.withSecurityRulesDisabled(async c=>{
  const d=c.firestore();
  for(const [uid,u]of Object.entries(users)){
   await setDoc(doc(d,'users/'+uid),u);
   if(u.activationId)await setDoc(doc(d,`accountBindings/${u.role}_${u.recipientId}`),{uid,accountStatus:'active'});
  }
  for(const id of ['P1','P2']){await setDoc(doc(d,'patients/'+id),{recordStatus:'active'});await setDoc(doc(d,'patientProfiles/'+id),{name:'Synthetic Patient'});}
  for(const r of ['R1','R2'])await setDoc(doc(d,`patientRelativeLinks/${r}_P1`),{active:true});
 });
});
after(async()=>env?.cleanup());
function ticket(uid='patient'){
 const u=users[uid],id='FC-'+String(++sequence).padStart(20,'0');
 return {concernId:id,submittedByUid:uid,submittedByRole:u.role,patientId:u.patientId,
 relativeId:u.role==='relative'?u.recipientId:null,concernType:'Schedule Concern',relatedArea:'Schedule',
 subject:'Synthetic schedule question',message:'First line\nSecond line',status:'Submitted',createdAt:serverTimestamp(),updatedAt:serverTimestamp(),
 resolvedAt:null,closedAt:null,revision:0,responseCount:0,lastResponseId:'',updatedBy:uid};
}
async function create(uid='patient'){const t=ticket(uid);await setDoc(doc(db(uid),'feedbackConcerns/'+t.concernId),t);return t;}
const ref=(uid,t)=>doc(db(uid),'feedbackConcerns/'+t.concernId);
const review=()=>({status:'Under Review',revision:1,updatedAt:serverTimestamp(),updatedBy:'staff'});

test('Patient creates and queries only own authenticated concerns',async()=>{
 const t=await create();await assertSucceeds(getDoc(ref('patient',t)));
 await assertSucceeds(getDocs(query(collection(db('patient'),'feedbackConcerns'),where('submittedByUid','==','patient'))));
 await assertFails(getDocs(collection(db('patient'),'feedbackConcerns')));
 await assertSucceeds(getDocs(collection(db('staff'),'feedbackConcerns')));
});
test('designated Relative submits only its own currently linked concern',async()=>{
 const t=await create('relative');await assertSucceeds(getDoc(ref('relative',t)));
 await assertFails(getDoc(ref('otherRelative',t)));
 const unlinked=ticket('unlinked');await assertFails(setDoc(ref('unlinked',unlinked),unlinked));
});
test('anonymous, unrelated accounts, and impersonated identities are rejected',async()=>{
 const t=await create();
 for(const who of [null,'other','relative','otherRelative','unlinked'])await assertFails(getDoc(ref(who,t)));
 for(const change of [{submittedByUid:'other'},{submittedByRole:'relative',relativeId:'R1'},{patientId:'P2'},{relativeId:'R1'}]){
  const bad={...ticket(),...change};await assertFails(setDoc(ref('patient',bad),bad));
 }
 const anonymous=ticket();await assertFails(setDoc(ref(null,anonymous),anonymous));
 const badRelative={...ticket('relative'),patientId:'P2'};await assertFails(setDoc(ref('relative',badRelative),badRelative));
});
test('required fields, category, limits, server time and initial state are enforced',async()=>{
 for(const change of [{subject:''},{subject:' '.repeat(5)},{message:''},{message:' \n '},{message:'x'.repeat(2001)},
  {concernType:'Invented'},{relatedArea:'Invented'},{status:'Resolved'},{revision:1},{createdAt:'forged'},{internalNote:'private'}]){
  const t={...ticket(),...change};await assertFails(setDoc(ref('patient',t),t));
 }
 const t=ticket();delete t.message;await assertFails(setDoc(ref('patient',t),t));
});
test('Mobile cannot edit original content, workflow, or create Staff replies',async()=>{
 const t=await create();
 for(const change of [{message:'replacement'},{status:'Resolved'},{updatedBy:'staff'},{responseCount:1}])await assertFails(updateDoc(ref('patient',t),change));
 await assertFails(setDoc(doc(db('patient'),`feedbackConcerns/${t.concernId}/responses/R-1`),{message:'pretend staff'}));
 await assertFails(deleteDoc(ref('patient',t)));
});
test('Staff transitions are sequential and original content remains immutable',async()=>{
 const t=await create();
 await assertFails(updateDoc(ref('staff',t),{...review(),status:'Resolved'}));
 await assertFails(updateDoc(ref('staff',t),{...review(),message:'edited by Staff'}));
 await assertFails(updateDoc(ref('staff',t),{...review(),updatedBy:'patient'}));
 await assertSucceeds(updateDoc(ref('staff',t),review()));
 await assertFails(updateDoc(ref('staff',t),{...review(),revision:2,status:'Submitted'}));
 await assertSucceeds(updateDoc(ref('staff',t),{status:'Resolved',revision:2,updatedBy:'staff',updatedAt:serverTimestamp(),resolvedAt:serverTimestamp()}));
 await assertSucceeds(updateDoc(ref('staff',t),{status:'Closed',revision:3,updatedBy:'staff',updatedAt:serverTimestamp(),closedAt:serverTimestamp()}));
 await assertFails(updateDoc(ref('staff',t),{...review(),revision:4}));
 await assertFails(deleteDoc(ref('staff',t)));
});
test('Staff responses append atomically, preserve history and restrict readers',async()=>{
 const t=await create('relative'),d=db('staff');
 for(let revision=1;revision<=2;revision++){
  const responseId='R-'+revision,b=writeBatch(d);
  b.update(doc(d,'feedbackConcerns/'+t.concernId),{status:'Under Review',revision,responseCount:revision,lastResponseId:responseId,updatedBy:'staff',updatedAt:serverTimestamp()});
  b.set(doc(d,`feedbackConcerns/${t.concernId}/responses/${responseId}`),{responseId,responderUid:'staff',responderRole:'staff',message:'Synthetic response '+revision,createdAt:serverTimestamp()});
  await assertSucceeds(b.commit());
 }
 const path=`feedbackConcerns/${t.concernId}/responses/R-1`;
 await assertSucceeds(getDoc(doc(db('relative'),path)));
 for(const who of ['patient','otherRelative',null])await assertFails(getDoc(doc(db(who),path)));
 await assertFails(updateDoc(doc(d,path),{message:'overwritten'}));await assertFails(deleteDoc(doc(d,path)));
 await assertFails(updateDoc(ref('staff',t),{revision:3,responseCount:3,lastResponseId:'R-3',updatedBy:'staff',updatedAt:serverTimestamp()}));
 await assertFails(setDoc(doc(d,`feedbackConcerns/${t.concernId}/responses/R-3`),{responseId:'R-3',responderUid:'staff',responderRole:'staff',message:'orphan',createdAt:serverTimestamp()}));
});
test('revoked links, disabled bindings and archived Patients deny existing concern access',async()=>{
 const t=await create('relative');
 await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'patientRelativeLinks/R1_P1'),{active:false}));
 await assertFails(getDoc(ref('relative',t)));
 const p=await create();
 await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'accountBindings/patient_P1'),{accountStatus:'disabled'}));
 await assertFails(getDoc(ref('patient',p)));
 await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'patients/P1'),{recordStatus:'archived'}));
 await assertFails(getDoc(ref('otherRelative',t)));
 await assertSucceeds(getDoc(ref('staff',t)));
});

test('new concern atomically notifies only the Staff inbox; Mobile cannot forge notices',async()=>{
 const t=ticket(),d=db('patient'),id='concern_submitted_'+t.concernId;
 const notice={id,eventId:id,patientId:'P1',recipientId:'staff',recipientType:'staff',recipientName:'Staff',recipientKey:'staff:all',type:'concernSubmitted',title:'New Feedback & Concern',message:'New Feedback & Concern submitted. Open the inbox to review it.',trigger:'automatic',sessionId:'',attempts:[],readAt:null,staffRead:false,createdAt:serverTimestamp()};
 const b=writeBatch(d);b.set(doc(d,'feedbackConcerns/'+t.concernId),t);b.set(doc(d,'notifications/'+id),notice);await assertSucceeds(b.commit());
 await assertSucceeds(getDoc(doc(db('staff'),'notifications/'+id)));
 await assertFails(getDoc(doc(d,'notifications/'+id)));
 await assertFails(updateDoc(doc(d,'notifications/'+id),{staffRead:true}));
 const forged={...notice,id:'forged',eventId:'forged',message:'private arbitrary message'};await assertFails(setDoc(doc(d,'notifications/forged'),forged));
});
test('future schedule changes are immutable, linked, and contain no private audit fields',async()=>{
 const d=db('staff'),session={id:'H-S',patientId:'P1',start:'2026-11-01T00:00:00Z',batch:'Batch A',room:'Room A',plannedDurationMinutes:240,status:'Pending',revision:0,progress:0};
 const after={start:session.start,batch:session.batch,room:session.room,plannedDurationMinutes:240};
 const history={id:'H-1',patientId:'P1',sessionId:'H-S',before:null,after,createdAt:serverTimestamp()};
 const b=writeBatch(d);b.set(doc(d,'sessions/H-S'),session);b.set(doc(d,'scheduleHistory/H-1'),history);await assertSucceeds(b.commit());
 for(const who of ['staff','patient','relative'])await assertSucceeds(getDoc(doc(db(who),'scheduleHistory/H-1')));
 for(const who of ['other','unlinked',null])await assertFails(getDoc(doc(db(who),'scheduleHistory/H-1')));
 await assertSucceeds(getDocs(query(collection(db('patient'),'scheduleHistory'),where('patientId','==','P1'))));
 await assertFails(getDocs(query(collection(db('patient'),'scheduleHistory'),where('patientId','==','P2'))));
 await assertFails(updateDoc(doc(d,'scheduleHistory/H-1'),{after:{...after,room:'Rewritten'}}));
 await assertFails(deleteDoc(doc(d,'scheduleHistory/H-1')));
 await assertFails(setDoc(doc(db('patient'),'scheduleHistory/forged'),{...history,id:'forged'}));
 await assertFails(setDoc(doc(d,'scheduleHistory/private'),{...history,id:'private',actorUid:'staff',internalNote:'private'}));
});
test('schedule history records real before/after edits, not fabricated historical snapshots',async()=>{
 const d=db('staff'),s={id:'S-EDIT',patientId:'P1',start:'2026-11-01T00:00:00Z',batch:'Batch A',room:'Room A',plannedDurationMinutes:240,status:'Pending',revision:0,progress:0};
 await setDoc(doc(d,'sessions/S-EDIT'),s);
 const before={start:s.start,batch:s.batch,room:s.room,plannedDurationMinutes:240},after={...before,start:'2026-11-02T00:00:00Z'};
 const b=writeBatch(d);b.update(doc(d,'sessions/S-EDIT'),{start:after.start,revision:1});b.set(doc(d,'scheduleHistory/EDIT'),{id:'EDIT',patientId:'P1',sessionId:'S-EDIT',before,after,createdAt:serverTimestamp()});await assertSucceeds(b.commit());
 await assertFails(setDoc(doc(d,'scheduleHistory/FABRICATED'),{id:'FABRICATED',patientId:'P1',sessionId:'S-EDIT',before:{...before,start:'invented'},after,createdAt:serverTimestamp()}));
 // Both ternary branches return booleans: an existing session cannot claim
 // a null previous schedule, and a new session cannot invent a previous map.
 await assertFails(setDoc(doc(d,'scheduleHistory/NULL-BEFORE'),{id:'NULL-BEFORE',patientId:'P1',sessionId:'S-EDIT',before:null,after,createdAt:serverTimestamp()}));
 const invented=writeBatch(d);
 invented.set(doc(d,'sessions/S-NEW-BEFORE'),{...s,id:'S-NEW-BEFORE'});
 invented.set(doc(d,'scheduleHistory/INVENTED-BEFORE'),{id:'INVENTED-BEFORE',patientId:'P1',sessionId:'S-NEW-BEFORE',before:{...before,start:'invented'},after:before,createdAt:serverTimestamp()});
 await assertFails(invented.commit());
});
