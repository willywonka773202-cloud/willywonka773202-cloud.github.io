// Refresh the reviewed public fallback during the weekly portfolio maintenance run.
// Uses the same bounded, validated public feed parser as the deployed function.
const fs=require('node:fs'),path=require('node:path'),handler=require('../api/channel.cjs');
let payload;
(async()=>{
 await handler({method:'GET'},{writeHead(){},end(body){payload=JSON.parse(body);}});
 if(payload.status!=='fresh')throw new Error('Public YouTube feed unavailable; existing snapshot preserved.');
 const file=path.resolve(__dirname,'../data/channel.json'),channel=JSON.parse(fs.readFileSync(file,'utf8'));
 channel.episodes=payload.episodes;
 channel.reviewed=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Los_Angeles',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
 const tmp=file+'.tmp';fs.writeFileSync(tmp,JSON.stringify(channel,null,2)+'\n');fs.renameSync(tmp,file);
 console.log('Saved verified channel fallback:',channel.episodes[0].id,channel.reviewed);
})().catch(error=>{console.error(error.message);process.exitCode=1;});
