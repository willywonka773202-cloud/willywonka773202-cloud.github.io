// Public channel feed only. No keys, visitor data, or arbitrary upstream URLs.
const fallback = require('../data/channel.json');
const FEED = 'https://www.youtube.com/feeds/videos.xml?channel_id=UCAIZGfaGkblFXoQjMwPkc-A';
function decode(value) {
  return value.replace(/&(#x[\da-f]+|#\d+|amp|lt|gt|quot|apos);/gi, (_, entity) => {
    if (entity[0] === '#') { const n = entity[1].toLowerCase() === 'x' ? parseInt(entity.slice(2), 16) : Number(entity.slice(1)); return n > 0 && n <= 0x10ffff ? String.fromCodePoint(n) : ''; }
    return {amp:'&',lt:'<',gt:'>',quot:'"',apos:"'"}[entity.toLowerCase()];
  });
}
function parseFeed(xml) {
  return [...xml.matchAll(/<entry>([\s\S]*?)<\/entry>/g)].map(([,entry]) => {
    const get = tag => decode(entry.match(new RegExp(`<${tag}>([\\s\\S]*?)</${tag}>`))?.[1] || '');
    const id=get('yt:videoId'), title=get('title'), published=get('published');
    return {id,title:title.replace(/\s*#shorts\b/ig,''),format:/#shorts\b/i.test(title)?'Short':'Episode',published,url:`https://www.youtube.com/watch?v=${id}`};
  }).filter(e => /^[\w-]{11}$/.test(e.id) && e.title && Number.isFinite(Date.parse(e.published)))
    .sort((a,b)=>Date.parse(b.published)-Date.parse(a.published)).slice(0,6);
}
async function handler(req,res) {
  if (!['GET','HEAD'].includes(req.method)) { res.writeHead(405,{'Allow':'GET, HEAD'}); return res.end(); }
  let payload;
  try {
    const response=await fetch(FEED,{signal:AbortSignal.timeout(5000)});
    if (!response.ok) throw new Error('Feed unavailable');
    const xml=await response.text();
    if (xml.length>300000) throw new Error('Feed too large');
    const episodes=parseFeed(xml);
    if (!episodes.length) throw new Error('Empty feed');
    payload={status:'fresh',checkedAt:new Date().toISOString(),episodes};
  } catch {
    payload={status:'snapshot',checkedAt:null,reviewed:fallback.reviewed,episodes:fallback.episodes};
  }
  res.writeHead(200,{'Content-Type':'application/json; charset=utf-8','Cache-Control':payload.status==='fresh'?'public, max-age=60, s-maxage=900, stale-while-revalidate=300':'public, max-age=30, s-maxage=60','X-Content-Type-Options':'nosniff'});
  res.end(req.method==='HEAD'?'':JSON.stringify(payload));
}
module.exports=handler;
module.exports.parseFeed=parseFeed;
