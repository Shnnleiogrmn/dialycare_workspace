'use strict';
const path=require('node:path'),{spawnSync}=require('node:child_process');
const cli=path.join(process.env.APPDATA,'npm/node_modules/firebase-tools/lib');
const {selectAccount,setActiveAccount}=require(path.join(cli,'auth')),{requireAuth}=require(path.join(cli,'requireAuth'));
const {getAccessToken}=require(path.join(cli,'apiv2'));
const bundled=path.join(process.env.USERPROFILE,'.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe');
const ps=require('node:fs').existsSync(bundled)?bundled:'powershell.exe';
const script=`$ErrorActionPreference='Stop'; $r=[Console]::In.ReadToEnd() | ConvertFrom-Json; try { $p=@{Uri=$r.url;Method=$r.method;Headers=@{};TimeoutSec=25}; if ($r.token) {$p.Headers.Authorization=('Bearer '+$r.token)}; if($null -ne $r.body){$p.ContentType='application/json';$p.Body=($r.body|ConvertTo-Json -Depth 50 -Compress)}; Invoke-RestMethod @p | ConvertTo-Json -Depth 50 -Compress } catch { [Console]::Error.WriteLine($_.Exception.Message); if ($_.ErrorDetails.Message) { [Console]::Error.WriteLine($_.ErrorDetails.Message) }; exit 1 }`;
async function connect(){
 const project='dialycare-backend-3f0ed',options={project,projectId:project,nonInteractive:true};
 setActiveAccount(options,selectAccount(undefined,__dirname));await requireAuth(options);
 const token=await getAccessToken();
 return function request(url,method='GET',body,requestToken=token){
  const r=spawnSync(ps,['-NoProfile','-NonInteractive','-Command',script],{input:JSON.stringify({url,method,body,token:requestToken}),encoding:'utf8',maxBuffer:1024*1024});
  if(r.status!==0)throw Error(r.stderr.trim()||'PowerShell request failed');return JSON.parse(r.stdout);
 };
}
module.exports={connect};
if(require.main===module)connect().then(request=>{
 const base='https://firestore.googleapis.com/v1/projects/dialycare-backend-3f0ed/databases/(default)';
 const d=request(base),c=request(`${base}/documents:listCollectionIds`,'POST',{pageSize:1000});
 console.log(JSON.stringify({name:d.name,locationId:d.locationId,createTime:d.createTime,collectionIds:c.collectionIds||[],hasMore:!!c.nextPageToken}));
}).catch(e=>{console.error(e.message);process.exitCode=1;});

