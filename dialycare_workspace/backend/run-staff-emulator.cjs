const {spawnSync}=require('node:child_process');
const path=require('node:path');
const result=spawnSync('flutter.bat',['test','test/spark_repository_flow_test.dart'],{
 cwd:path.resolve(__dirname,'../dialycare_staff'),stdio:'inherit',shell:true,env:process.env,
});
process.exitCode=result.status ?? 1;
