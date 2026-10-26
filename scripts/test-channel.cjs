const assert=require('node:assert/strict');
const handler=require('../api/channel.cjs');
const sample='<feed><entry><yt:videoId>k6tir5JtpCM</yt:videoId><title>Old &amp; useful</title><published>2026-10-25T00:00:00Z</published></entry><entry><yt:videoId>WBrTNlQij3Y</yt:videoId><title>New &#x26; clear #Shorts</title><published>2026-10-26T00:00:00Z</published></entry><entry><yt:videoId>invalid</yt:videoId><title>Invalid</title><published>bad</published></entry></feed>';
const result=handler.parseFeed(sample);assert.equal(result.length,2);assert.equal(result[0].id,'WBrTNlQij3Y');assert.equal(result[0].title,'New & clear');assert.equal(result[0].format,'Short');
const originalFetch=global.fetch;
async function invoke(){let status,headers,body;await handler({method:'GET'},{writeHead:(s,h)=>{status=s;headers=h;},end:b=>{body=JSON.parse(b);}});return {status,headers,body};}
(async()=>{
 global.fetch=async()=>({ok:true,text:async()=>sample});let r=await invoke();assert.equal(r.body.status,'fresh');assert.equal(r.body.episodes[0].id,'WBrTNlQij3Y');assert.match(r.headers['Cache-Control'],/s-maxage=900/);
 global.fetch=async()=>{throw new Error('Offline');};r=await invoke();assert.equal(r.body.status,'snapshot');assert.ok(r.body.episodes.length);assert.equal(r.body.checkedAt,null);
 global.fetch=async()=>({ok:true,text:async()=>'<feed></feed>'});r=await invoke();assert.equal(r.body.status,'snapshot');global.fetch=originalFetch;
 console.log('PASS: chronological feed, entity decoding, validation, cached fresh response and honest offline/empty-feed fallback.');
})().catch(e=>{global.fetch=originalFetch;console.error(e);process.exitCode=1;});
