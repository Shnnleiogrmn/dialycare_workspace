const {test}=require('node:test'),assert=require('node:assert/strict');
const {dataset,seedKey}=require('./synthetic-dataset.cjs');
test('one deterministic synthetic dataset has 22/21 Patients, 43 unique relatives and safe identifiers',()=>{
 const rows=dataset();assert.deepEqual(rows,dataset());assert.equal(rows.length,43);
 assert.equal(rows.filter(r=>r.patient.scheduleGroup==='MWF').length,22);
 assert.equal(rows.filter(r=>r.patient.scheduleGroup==='TTHS').length,21);
 for(const entity of ['patient','relative']){assert.equal(new Set(rows.map(r=>r[entity].id)).size,43);assert.equal(new Set(rows.map(r=>r[entity].name)).size,43);}
 for(const row of rows){assert.equal(row.patient.demonstrationSeed,seedKey);assert.equal(row.patient.synthetic,true);assert.equal(row.patient.philHealthNumber,'');assert.equal(row.patient.age,undefined);assert.match(row.patient.birthDate,/^\d{4}-/);assert.match(row.patient.contact,/DEMO/);assert.match(row.relative.contact,/DEMO/);assert.ok(['Daughter','Son','Sister','Brother'].includes(row.relationship));assert.equal(row.patient.mdrStatus,'Unknown');assert.ok([180,210,240,270,300].includes(row.plannedDurationMinutes));assert.match(row.patient.room,/^Room 0[1-6]$/);assert.match(row.patient.batch,/^Batch [ABC]$/);}
});
