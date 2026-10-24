// Local verification session: an actual MCP stdio client and an isolated Chromium.
import {Client} from '../../mcp/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js';
import {StdioClientTransport} from '../../mcp/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js';
import puppeteer from 'puppeteer-core';
import {createServer} from 'node:http';
import {readFile, writeFile, mkdir} from 'node:fs/promises';
import {resolve} from 'node:path';
const out=resolve('_local/pirate68k');
await mkdir(out,{recursive:true});
const client=new Client({name:'pirate68k-verifier',version:'1.0'});
const transport=new StdioClientTransport({command:process.execPath,args:['mcp/server.mjs'],env:{...process.env,WEBX68K_BRIDGE_PORT:'3199'}});
await client.connect(transport);
const browser=await puppeteer.launch({executablePath:process.env.CHROME_BIN||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--autoplay-policy=no-user-gesture-required','--disable-background-timer-throttling','--disable-renderer-backgrounding']});
const page=await browser.newPage();
await page.setViewport({width:1280,height:1000});
page.on('pageerror',e=>console.error('PAGE:',e.message));
page.on('console',m=>{if(m.type()==='error')console.error('CONSOLE:',m.text());});
async function call(name,args={}){
 const r=await client.callTool({name,arguments:args},undefined,{timeout:120000});
 if(r.isError)throw new Error(JSON.stringify(r));
 return r;
}
const held=new Set();
const server=createServer(async(req,res)=>{
 try{
  let body='';for await(const c of req)body+=c;
  const q=JSON.parse(body||'{}'); let r;
  if(req.url==='/keyboard'){
   // Physical keyboard input is accepted only while the emulator canvas owns focus.
   await page.focus('#screen');
   const wanted=new Set(q.keys||[]);
   for(const k of held)if(!wanted.has(k)){await page.keyboard.up(k);held.delete(k);}
   for(const k of wanted)if(!held.has(k)){await page.keyboard.down(k);held.add(k);}
   r={keys:[...held],focus:await page.evaluate(()=>document.activeElement?.id)};
  }else if(req.url==='/open'){
   await page.goto(q.url,{waitUntil:'networkidle0',timeout:60000});r={url:page.url()};
  }else if(req.url==='/insert'){
   r=await call('insert_disk',{slot:q.slot,name:q.name||q.path.split('/').at(-1),data_base64:(await readFile(q.path)).toString('base64')});
  }else if(req.url==='/shot'){
   r=await call('screenshot');const c=r.content.find(c=>c.type==='image');await writeFile(resolve(out,q.name+'.png'),Buffer.from(c.data,'base64'));r={image:q.name+'.png'};
  }else if(req.url==='/get'){
   r=await call('disk_read_file',{slot:q.slot,path:q.path});const v=JSON.parse(r.content[0].text);await writeFile(resolve(out,q.name),Buffer.from(v.base64||v.data_base64,'base64'));r={keys:Object.keys(v),saved:q.name};
  }else r=await call(q.name,q.args||{});
  const logged=(q.name==='read_memory'||q.name==='disk_read_file')?{read:true}:r;
  await writeFile(resolve(out,'session.jsonl'),JSON.stringify({time:new Date().toISOString(),request:{...q,data_base64:undefined},response:logged})+'\n',{flag:'a'});
  res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify(r));
 }catch(e){res.writeHead(500);res.end(String(e));}
});
server.listen(5399,'127.0.0.1');
console.log('MCP control: http://127.0.0.1:5399; bridge:3199');
let closing=false;
async function shutdown(){
 if(closing)return;closing=true;
 server.close();await browser.close();await client.close();process.exit();
}
process.on('SIGINT',shutdown);
process.on('SIGTERM',shutdown);
process.on('SIGHUP',shutdown);
