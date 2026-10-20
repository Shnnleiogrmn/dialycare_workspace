'use strict';
// Read-only verification of the approved cohort and scheduling invariants.
const assert=require('node:assert/strict');
const {connect}=require('./inspect-database-powershell.cjs');
const {dataset,seedKey}=require('./synthetic-dataset.cjs');
(async()=>{
 const r=await connect(),url='https://firestore.googleapis.com/v1/projects/dialycare-backend-3f0ed/databases/(default)/documents';
 const value=v=>'stringValue'in v?v.stringValue:'integerValue'in v?Number(v.integerValue):'booleanValue'in v?v.booleanValue:null;
 function query(collection,fields){const rows=r(url+':runQuery','POST',{structuredQuery:{from:[{collectionId:collection}],select:{fields:fields.map(fieldPath=>({fieldPath}))}}});return(Array.isArray(rows)?rows:[rows]).filter(x=>x.document).map(x=>Object.fromEntries(Object.entries(x.document.fields||{}).map(([k,v])=>[k,value(v)])));}
 const patients=query('patients',['id','publicId','scheduleGroup','demonstrationSeed']),relatives=query('relatives',['id','publicId']);
 const links=query('patientRelativeLinks',['patientId','relativeId','relationship','active']);
 const sessions=query('sessions',['id','patientId','start','room','batch','scheduleGroup','plannedDurationMinutes']);
 let changedDesignatedRelatives=0;
 const cohort=patients.filter(p=>p.demonstrationSeed===seedKey),ids=new Set(cohort.map(p=>p.id));
 assert.equal(cohort.length,43);assert.equal(cohort.filter(p=>p.scheduleGroup==='MWF').length,22);assert.equal(cohort.filter(p=>p.scheduleGroup==='TTHS').length,21);
 for(const records of [patients,relatives])assert.equal(new Set(records.map(p=>p.publicId)).size,records.length);
 for(let index=0;index<43;index++){
  const expected=dataset()[index],patient=cohort.find(p=>p.id===expected.patient.id),relative=relatives.find(p=>p.id===expected.relative.id);
  assert.equal(patient.publicId,'DC-'+String(index+5).padStart(6,'0'));assert.equal(relative.publicId,'R-'+String(index+5).padStart(6,'0'));
  // Staff can legitimately replace designated identities/contact details after
  // seeding. Preserve immutable original IDs and validate the current link.
  const current=links.filter(l=>l.patientId===patient.id&&l.active);
  assert.equal(current.length,1,'Patient must have one current designated Relative');
  assert.ok(relatives.some(r=>r.id===current[0].relativeId));
  assert.ok(typeof current[0].relationship==='string'&&current[0].relationship.length>0);
  if(current[0].relativeId!==relative.id)changedDesignatedRelatives++;

 }
 const appointments=sessions.filter(s=>ids.has(s.patientId));assert.equal(appointments.length,43);assert.equal(new Set(appointments.map(s=>s.patientId)).size,43);
 const day=s=>new Date(new Date(s.start).getTime()+8*3600000);
 for(const s of appointments){const local=day(s),patient=cohort.find(p=>p.id===s.patientId);assert.equal(s.scheduleGroup,patient.scheduleGroup);assert.ok((s.scheduleGroup==='MWF'?[1,3,5]:[2,4,6]).includes(local.getUTCDay()));assert.ok([180,210,240,270,300].includes(s.plannedDurationMinutes));assert.ok([6,12,18].includes(local.getUTCHours()));}
 for(let i=0;i<appointments.length;i++)for(let j=i+1;j<appointments.length;j++){
  const a=appointments[i],b=appointments[j];if(a.room!==b.room)continue;
  const startA=Date.parse(a.start),startB=Date.parse(b.start);
  assert.ok(startA+a.plannedDurationMinutes*60000<=startB||startB+b.plannedDurationMinutes*60000<=startA,'Overlapping seeded room slots');
 }
 // Original occupied dates were checked by the seed's before/after audit. Later
 // legitimate appointments may use those dates; never reset current care data.

 console.log(JSON.stringify({result:'SYNTHETIC_COHORT_AND_SCHEDULE_VERIFIED',MWF:22,TTHS:21,syntheticPatients:43,totalPatients:patients.length,relativeLinksVerified:43,syntheticAppointments:43,totalSessions:sessions.length,patientIdRange:'DC-000005–DC-000047',originalSeedRelativeIdRange:'R-000005–R-000047',duplicatePublicIds:0,seededRoomOverlaps:0,groupWeekdaysCorrect:true,originalSeedIdsRetained:true,currentDesignatedRelativesVerified:true,changedDesignatedRelatives,historicalRelativeIdentities:relatives.length-links.filter(l=>l.active).length}));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
