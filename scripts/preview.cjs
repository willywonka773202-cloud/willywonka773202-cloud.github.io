// One lightweight local server for the static site and its public feed endpoint.
const http=require('node:http'),fs=require('node:fs'),path=require('node:path');
const channel=require('../api/channel.cjs'),root=path.resolve(__dirname,'../dist');
const types={'.html':'text/html','.js':'text/javascript','.css':'text/css','.svg':'image/svg+xml','.jpg':'image/jpeg','.png':'image/png','.woff2':'font/woff2','.pdf':'application/pdf','.xml':'application/xml'};
http.createServer(async(req,res)=>{
 const url=new URL(req.url,'http://localhost');if(url.pathname==='/api/channel')return channel(req,res);
 let name;try{name=decodeURIComponent(url.pathname);}catch{res.writeHead(400);return res.end();}
 if(name.endsWith('/'))name+='index.html';const file=path.resolve(root,'.'+name);
 if(!file.startsWith(root+path.sep)||name.split('/').some(p=>p.startsWith('.'))){res.writeHead(404);return res.end();}
 try{const data=await fs.promises.readFile(file);res.writeHead(200,{'Content-Type':types[path.extname(file)]||'application/octet-stream'});res.end(req.method==='HEAD'?'':data);}catch{res.writeHead(404);res.end('Not found');}
}).listen(4198,'127.0.0.1',()=>console.log('Portfolio preview: http://127.0.0.1:4198'));
