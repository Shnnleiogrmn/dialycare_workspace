'use strict';
// Trusted, one-time schema migration. Does not create Auth users or handle passwords.
const {connect} = require('../inspect-database-powershell.cjs');
async function main() {
  const request = await connect();
  const base = 'https://firestore.googleapis.com/v1/projects/dialycare-backend-3f0ed/databases/(default)';
  const database = request(base);
  if (database.locationId !== 'asia-southeast1') throw Error('Unexpected database region; no changes made.');
  const rows = request(`${base}/documents:runQuery`, 'POST', {structuredQuery:{
    from:[{collectionId:'users'}],
    where:{fieldFilter:{field:{fieldPath:'role'},op:'IN',value:{arrayValue:{values:[{stringValue:'staff'},{stringValue:'admin'}]}}}},
  }});
  const docs = rows.filter(r => r.document).map(r => r.document);
  const pending = docs.filter(d => !d.fields.accountStatus);
  const writes = pending.map(d => {
    const disabled = d.fields.disabled?.booleanValue;
    if (typeof disabled !== 'boolean') throw Error('Malformed Staff mapping; manual review required.');
    return {update:{name:d.name,fields:{accountStatus:{stringValue:disabled?'disabled':'active'}}},
      updateMask:{fieldPaths:['accountStatus']},currentDocument:{updateTime:d.updateTime}};
  });
  const apply = process.argv.includes('--apply');
  if (apply && writes.length) request(`${base}/documents:commit`, 'POST', {writes});
  console.log(JSON.stringify({project:'dialycare-backend-3f0ed',location:database.locationId,
    staffMappings:docs.length,missingStatus:pending.length,updated:apply?writes.length:0,dryRun:!apply}));
}
main().catch(e => {console.error(e.message); process.exitCode=1;});
