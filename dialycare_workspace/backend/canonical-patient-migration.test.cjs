"use strict";
const {test}=require('node:test'),assert=require('node:assert/strict');
const {canonical,buildPlan,ROOT,verifyPublishedRules}=require('./canonical-patient-migration.cjs');
const {inspectIntegrity,requireIntegrity}=require('./patient-migration-integrity.cjs');
function doc(path,fields){return {name:ROOT+'/'+path,updateTime:'2026-10-24T00:00:00Z',fields:Object.fromEntries(Object.entries(fields).map(([k,v])=>[k,typeof v==='number'?{integerValue:String(v)}:v===null?{nullValue:null}:{stringValue:v}]))};}
function fixture(){return {patients:[doc('patients/internal-one',{id:'internal-one',publicId:'DC-000001'}),doc('patients/internal-five',{id:'internal-five',publicId:'DC-000005'})],
 patientProfiles:[doc('patientProfiles/internal-one',{id:'internal-one',publicId:'DC-000001'}),doc('patientProfiles/internal-five',{id:'internal-five',publicId:'DC-000005'})],
 publicIds:[doc('publicIds/DC-000049',{role:'patient',publicId:'DC-000049',internalId:'retired-fixture'})],
 sessions:[doc('sessions/S',{patientId:'internal-one'})],feedbackConcerns:[doc('feedbackConcerns/C',{patientId:'internal-one'})],
 clinical:[doc('clinical/state',{revision:1})],idCounters:[],invitations:[],users:[],accountBindings:[]};}
function apply(snapshot,writes){const copy=structuredClone(snapshot);for(const w of writes){const path=w.update.name.slice(ROOT.length+1),[collection]=path.split('/');copy[collection]??=[];const i=copy[collection].findIndex(d=>d.name===w.update.name);const old=i<0?{}:copy[collection][i];const updated={...old,name:w.update.name,updateTime:'2026-10-24T01:00:00Z',fields:{...(old.fields||{}),...w.update.fields}};if(i<0)copy[collection].push(updated);else copy[collection][i]=updated;}return copy;}
test('canonical IDs are exactly DP-YYYY-NNN and reject fabricated mappings',()=>{
 assert.equal(canonical('DC-000005',2026).id,'DP-2026-005');assert.equal(canonical('DP-2027-0005',2026).id,'DP-2027-005');
 for(const v of ['unknown','DC-000000','DC-001000','DP-2026-000'])assert.equal(canonical(v,2026),null);
});
test('dry run preserves numbers and retired reservations, without reference/Auth rewrites',()=>{
 const s=fixture(),before=JSON.stringify(s),p=buildPlan(s);
 assert.equal(p.plan.patientsToChange,2);assert.equal(p.plan.nextByYear[2026],50);assert.equal(p.plan.authAccountsChanged,0);assert.equal(p.plan.documentIdsRenamed,0);assert.equal(p.plan.foreignKeysRewritten,0);assert.deepEqual(p.plan.conflicts,[]);
 assert.equal(JSON.stringify(s),before);assert.ok(p.writes.every(w=>!w.update.name.includes('/sessions/')&&!w.update.name.includes('/feedbackConcerns/')));
});
test('migration plan is idempotent after applying only planned field patches',()=>{
 const s=fixture(),first=buildPlan(s),changed=apply(s,first.writes),second=buildPlan(changed);
 assert.equal(second.plan.patientsToChange,0);assert.equal(second.writes.length,0);assert.deepEqual(second.plan.conflicts,[]);
 assert.deepEqual(changed.sessions,s.sessions);assert.deepEqual(changed.feedbackConcerns,s.feedbackConcerns);
});
test('conflicting canonical target and missing authorized projection block apply',()=>{
 const s=fixture();s.publicIds.push(doc('publicIds/DP-2026-001',{role:'patient',internalId:'someone-else'}));
 assert.ok(buildPlan(s).plan.conflicts.length);
 const other=fixture();other.patientProfiles=[];assert.ok(buildPlan(other).plan.conflicts.length);
});
test('duplicate business identifiers cannot receive the same canonical reservation',()=>{
 const s=fixture();s.patients[1].fields.publicId={stringValue:'DP-2026-0001'};
 assert.ok(buildPlan(s).plan.conflicts.some(c=>c.reason.includes('Duplicate')));
});
test('pending invitation hashes remain stable; only display metadata changes',()=>{
 const s=fixture();s.invitations=[doc('invitations/unchanged-secret-capability',{role:'patient',recipientId:'internal-one',patientId:'internal-one',publicId:'DC-000001',patientPublicId:'DC-000001',usedBy:null})];
 const p=buildPlan(s);const invitation=p.writes.find(w=>w.update.name.includes('/invitations/'));
 assert.ok(invitation.update.name.endsWith('/unchanged-secret-capability'));assert.deepEqual(invitation.updateMask.fieldPaths.sort(),['patientPublicId','publicId']);
});
test('dry-run digest is stable and binds source preconditions',()=>{
 const s=fixture();assert.equal(buildPlan(s).plan.digest,buildPlan(s).plan.digest);
 const updated=fixture();updated.patients[0].updateTime='different';assert.notEqual(buildPlan(s).plan.digest,buildPlan(updated).plan.digest);
});

test('migration preflight rejects inactive or mismatched published policy before writes',()=>{
 const source='service cloud.firestore {\n reviewed policy\n}';
 const stub=content=>url=>url.endsWith('/releases/cloud.firestore')
  ? {rulesetName:'projects/dialycare-backend-3f0ed/rulesets/reviewed'}
  : {source:{files:[{content}]}};
 assert.throws(()=>verifyPublishedRules(stub('older policy'),source),/stopped before writes/);
 assert.doesNotThrow(()=>verifyPublishedRules(stub(source.replace(/\n/g,'\r\n')),source));
 assert.throws(()=>verifyPublishedRules(()=>({rulesetName:'projects/another-project/rulesets/other'}),source),/Unexpected published Rules project/);
});

function integrityFixture(){
 const s=fixture();s.patientAccountProfiles=s.patients.map(p=>doc('patientAccountProfiles/'+p.name.split('/').pop(),{}));
 s.relatives=[doc('relatives/R1',{})];
 s.users=[doc('users/relative-user',{role:'relative',patientId:'internal-one',recipientId:'R1',accountStatus:'active'})];
 s.accountBindings=[doc('accountBindings/relative_R1',{uid:'relative-user',role:'relative',patientId:'internal-one',recipientId:'R1'})];
 s.patientRelativeLinks=[doc('patientRelativeLinks/R1_internal-one',{patientId:'internal-one',relativeId:'R1'})];
 s.patientRelativeLinks[0].fields.active={booleanValue:true};
 return s;
}
test('integrity gate permits resolving references and blocks an active Relative with an inactive link',()=>{
 const s=integrityFixture();assert.equal(requireIntegrity(s).brokenReferences,0);
 s.patientRelativeLinks[0].fields.active={booleanValue:false};
 assert.ok(inspectIntegrity(s).issues.some(i=>i.reason==='Mobile Relative lacks active Patient link'));
 assert.throws(()=>requireIntegrity(s),/stopped before writes/);
 // A deliberately disabled account does not require an active care link.
 s.users[0].fields.disabled={booleanValue:true};
 assert.doesNotThrow(()=>requireIntegrity(s));
});
test('integrity gate rejects orphaned events, mismatched session ownership and bindings',()=>{
 const s=integrityFixture();s.sessionEvents=[doc('sessionEvents/event',{patientId:'internal-five',sessionId:'S'})];
 assert.ok(inspectIntegrity(s).issues.some(i=>i.reason==='Session belongs to another Patient'));
 s.sessionEvents[0].fields.sessionId={stringValue:'absent'};
 assert.ok(inspectIntegrity(s).issues.some(i=>i.reason==='Session reference does not resolve'));
 s.accountBindings[0].fields.uid={stringValue:'missing'};
 assert.ok(inspectIntegrity(s).issues.some(i=>i.reason==='Reverse account ownership mismatch'));
 assert.throws(()=>requireIntegrity(s),/stopped before writes/);
});

test('unactivated bindings resolve to their invitation without requiring a fabricated Auth user',()=>{
 const s=integrityFixture();
 s.accountBindings.push(doc('accountBindings/patient_internal-five',{uid:null,role:'patient',recipientId:'internal-five',patientId:'internal-five',accountStatus:'activationPending',activationId:'pending-capability'}));
 s.invitations=[doc('invitations/pending-capability',{role:'patient',recipientId:'internal-five',patientId:'internal-five',usedBy:null})];
 assert.doesNotThrow(()=>requireIntegrity(s));
 s.invitations=[];
 assert.throws(()=>requireIntegrity(s),/stopped before writes/);
});
