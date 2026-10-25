// Isolated guest build/play verification. Audio capture observes the mixer output;
// it does not change the emulator or inject sound/game state.
import assert from 'node:assert/strict';
import {Client} from '../../mcp/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js';
import {StdioClientTransport} from '../../mcp/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js';
import puppeteer from 'puppeteer-core';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const phase=process.argv[2];
assert(['build','rebuild','play','exit','missing','effects'].includes(phase),'Usage: HUMAN_XDF=... node verify-audio.mjs build|rebuild|play|exit|missing|effects');
const building=phase==='build'||phase==='rebuild';
const out='_local/pirate68k/audio-check';await mkdir(out,{recursive:true});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const client=new Client({name:'pirate68k-audio-verifier',version:'1.0'});
const transport=new StdioClientTransport({command:process.execPath,args:['mcp/server.mjs'],env:{...process.env,WEBX68K_BRIDGE_PORT:'3299'}});
let browser,page;
async function call(name,args={}){
 const r=await client.callTool({name,arguments:args},undefined,{timeout:120000});
 if(r.isError)throw Error(JSON.stringify(r));
 return name==='screenshot'?r:JSON.parse(r.content[0].text);
}
async function save(name,data){await writeFile(`${out}/${name}.json`,JSON.stringify(data,null,2)+'\n');}
async function shot(name){const r=await call('screenshot');await writeFile(`${out}/${name}.png`,Buffer.from(r.content.find(c=>c.type==='image').data,'base64'));}
async function wait(fn,timeout=45000){const end=Date.now()+timeout;do{const r=await fn();if(r)return r;await sleep(150);}while(Date.now()<end);throw Error('Guest state timed out');}
async function text(){return call('screen_text');}
async function type(text){return call('type_text',{text});}
async function key(code,ms=180){return call('key_sequence',{steps:[{code,ms}]});}
async function insert(slot,path){await call('insert_disk',{slot,name:path.split('/').at(-1),data_base64:(await readFile(path)).toString('base64')});}
let gameAddr,soundAddr;
async function memory(addr,length){return Buffer.from((await call('read_memory',{addr,length})).bytes);}
async function locate(){
 for(let addr=0x20000;addr<0x200000;addr+=65536){
  const b=await memory(addr,65536);
  let i=b.indexOf('P68KSTAT');if(i>=0)gameAddr=addr+i;
  i=b.indexOf('P68KSND!');if(i>=0)soundAddr=addr+i;
 }
 assert(gameAddr&&soundAddr,'Guest state markers absent');
}
async function state(){
 const b=await memory(gameAddr,272),a=await memory(soundAddr,34);
 return {mode:b.readUInt16BE(8),stage:b.readUInt16BE(10),x:b.readUInt16BE(12),y:b.readUInt16BE(14),score:b.readUInt32BE(16),kills:b.readUInt16BE(20),life:b.readUInt16BE(22),bombs:b.readUInt16BE(24),frame:b.readUInt32BE(28),shots:b.readUInt16BE(36),bosshp:b.readInt16BE(40),bossx:b.readUInt16BE(42),bossdx:b.readInt16BE(44),xspactive:b.readUInt16BE(68),videostage:b.readUInt16BE(74),enemies:Array.from({length:8},(_,i)=>({active:b.readUInt16BE(80+8*i),x:b.readUInt16BE(82+8*i),y:b.readUInt16BE(84+8*i)})),audio:{ready:a.readUInt16BE(8),version:a.readUInt16BE(10),bgm:a.readUInt16BE(12),bgmcalls:a.readUInt16BE(14),fm:a.readUInt16BE(16),pcm:a.readUInt16BE(18),lastfm:a.readUInt16BE(20),lastpcm:a.readUInt16BE(22),errors:a.readUInt16BE(24),result:a.readInt32BE(26)}};
}
const held=new Set();
async function keys(wanted){
 await page.focus('#screen');
 for(const k of held)if(!wanted.includes(k)){await page.keyboard.up(k);held.delete(k);}
 for(const k of wanted)if(!held.has(k)){await page.keyboard.down(k);held.add(k);}
}
async function capture(name,action){
 await page.evaluate(()=>{window.__pcm.chunks=[];window.__pcm.active=true;});
 await action();
 const samples=await page.evaluate(()=>{window.__pcm.active=false;return window.__pcm.chunks.flatMap(c=>Array.from(c));});
 assert(samples.length>0,'No mixer samples');
 const wav=Buffer.alloc(44+samples.length*2);wav.write('RIFF');wav.writeUInt32LE(wav.length-8,4);wav.write('WAVEfmt ',8);wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(2,22);wav.writeUInt32LE(44100,24);wav.writeUInt32LE(176400,28);wav.writeUInt16LE(4,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(samples.length*2,40);
 let peak=0,sum=0;const means=[0,0];for(let i=0;i<samples.length;i++){const s=samples[i];peak=Math.max(peak,Math.abs(s));sum+=s*s;means[i%2]+=s;wav.writeInt16LE(Math.round(Math.max(-1,Math.min(1,s))*32767),44+i*2);}
 const dc=means.map(s=>s/(samples.length/2));
 // The ADPCM mixer can hold a constant final DAC value after playback stops.
 // Measure the varying signal separately from that per-channel DC component.
 const acRms=Math.sqrt(Math.max(0,sum/samples.length-(dc[0]*dc[0]+dc[1]*dc[1])/2));
 const result={seconds:samples.length/88200,peak,rms:Math.sqrt(sum/samples.length),dc,acRms};
 await writeFile(`${out}/${name}.wav`,wav);await save(name,result);console.log(name,result);return result;
}
try{
 await client.connect(transport);
 browser=await puppeteer.launch({executablePath:process.env.CHROME_BIN||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--autoplay-policy=no-user-gesture-required','--disable-background-timer-throttling','--disable-renderer-backgrounding']});
 page=await browser.newPage();
 await page.evaluateOnNewDocument(()=>{
  window.__pcm={active:false,chunks:[]};const Original=window.AudioWorkletNode;
  window.AudioWorkletNode=class extends Original{constructor(...args){super(...args);const post=this.port.postMessage.bind(this.port);this.port.postMessage=(data,...rest)=>{if(window.__pcm.active&&data instanceof Float32Array)window.__pcm.chunks.push(Array.from(data));return post(data,...rest);};}};
 });
 await page.goto(`http://127.0.0.1:5299/?bridge=3299&system=1&run=1&cpu=16&ram=${building?8:2}`,{waitUntil:'networkidle0'});
 await wait(async()=>{try{return await call('status');}catch{return false;}});
 await insert('fdd0',process.env.HUMAN_XDF);
 await insert('fdd1',`_local/pirate68k/${building?'audio-dev':phase==='effects'?'audio-effects-probe':'release-audio'}.xdf`);
 await call('reset');
 await wait(async()=>{const r=await text();return r.lines?.some(l=>l.includes('Command version'))&&r;});
 await save(`${phase}-boot`,await text());
 if(building){
  await type('B:\\BUILD\n');
  const log=await wait(async()=>{const r=await text();if(r.lines.some(l=>l.includes('BUILD FAILED')))throw Error(JSON.stringify(r));return r.lines.some(l=>l.includes('BUILD OK:'))&&r;},60000);
  await save(phase==='build'?'guest-build':'guest-rebuild',log);await shot(phase==='build'?'guest-build':'guest-rebuild');
  const r=await call('disk_read_file',{slot:'fdd1',path:'/OUT/PIRATE.X'});
  const x=Buffer.from(r.data_base64,'base64');
  if(phase==='rebuild')assert(x.equals(await readFile('_local/pirate68k/PIRATE-audio.X')),'Guest rebuild differs');
  else await writeFile('_local/pirate68k/PIRATE-audio.X',x);
  const result={result:'PASS',bytes:x.length,sha256:createHash('sha256').update(x).digest('hex')};
  await save(phase,result);console.log(phase,result);
 }else if(phase==='missing'){
  await type('B:\nPIRATE\n');
  const r=await wait(async()=>{const r=await text();return r.lines.some(l=>l.includes('Z-MUSIC v2 required'))&&r;});
  await save('missing-driver',r);await shot('missing-driver');console.log('Missing driver handled PASS');
 }else if(phase==='effects'){
  await type('B:\nGO\n');
  await wait(async()=>{const r=await text();if(r.lines.some(l=>/Cannot load|error occurred/i.test(l)))throw Error(JSON.stringify(r));return (await call('status')).screen.width===256;});
  await locate();await key(122);await sleep(1000);
  const silent=await capture('effects-silence',()=>sleep(700));assert(silent.acRms<0.001);
  const fm=await capture('isolated-fm',async()=>{await keys(['z']);await sleep(800);await keys([]);});assert(fm.acRms>0.001);
  await sleep(1800);
  const pcm=await capture('isolated-zpd',async()=>{await key(120,200);await sleep(900);});assert(pcm.acRms>0.001);
  await save('isolated-effects-state',await state());console.log('Isolated FM and ZPD output PASS');
 }else if(phase==='exit'){
  await type('B:\nGO\n');
  await wait(async()=>(await call('status')).screen.width===256);
  await key(122);await sleep(1000);await key(120);await key(27);
  await wait(async()=>{const r=await call('status');return r.screen.width===768&&r.screen.height===512&&r;});
  await type('ECHO AUDIOEXITOK\n');
  const exit=await wait(async()=>{const r=await text();return r.lines.some(l=>l.trim().toUpperCase()==='AUDIOEXITOK')&&r;});
  await save('exit',exit);await shot('exit');
  const silence=await capture('exit-silence',()=>sleep(1200));assert(silence.acRms<0.001);
  await type('PIRATE\n');
  const missing=await wait(async()=>{const r=await text();return r.lines.some(l=>l.includes('Z-MUSIC v2 required'))&&r;});
  await save('missing-driver',missing);await shot('missing-driver');
  await save('exit-result',{result:'PASS',ramMB:2,exit:true,driverReleased:true,missingDriverHandled:true});
  console.log('Exit, silence and missing-driver handling PASS');
 }else{
  await type('B:\nGO\n');
  await wait(async()=>{const r=await text();if(r.lines.some(l=>/Cannot load|driver failed|error occurred/i.test(l)))throw Error(JSON.stringify(r));return (await call('status')).screen.width===256;});
  await locate();let s=await state();await save('title-state',s);assert.equal(s.audio.ready,1);assert.equal(s.audio.bgm,1);await shot('title');
  const title=await capture('title-bgm',()=>sleep(2200));assert(title.acRms>0.001);
  await key(122);await wait(async()=>{const r=await state();return r.frame>=3&&r.xspactive===1&&r.videostage===1&&r;});
  await capture('stage-bgm',()=>sleep(2000));await shot('stage1');
  const before=await state();
  await capture('shot-fm',async()=>{await keys(['z']);await sleep(1400);await keys([]);});
  s=await state();assert(s.audio.fm>before.audio.fm);assert.equal(s.audio.errors,0);await save('shot-state',s);
  await capture('bomb-pcm',()=>key(120,200));s=await state();assert(s.audio.pcm>before.audio.pcm);await save('bomb-state',s);await shot('bomb');
  // Leave the real game idle to verify damage/game-over music.
  await wait(async()=>{const r=await state();return r.mode===2&&r;},90000);
  await capture('gameover-bgm',()=>sleep(2000));s=await state();assert.equal(s.audio.bgm,5);await save('gameover-state',s);await shot('gameover');
  // Restart once and observe the completed initialization, then play both bosses.
  await key(122);await sleep(800);await wait(async()=>{const r=await state();return r.mode===1&&r.frame>=3&&r.frame<35&&r;});
  const trace=[];
  for(const stage of [1,2]){
   // Wait at the right edge so the first six enemies can gather without contact.
   await wait(async()=>{const r=await state();trace.push(r);if(r.mode===2){await save('pilot-trace',trace);throw Error('Pilot game over before boss');}await keys(r.x<212?['ArrowRight']:[]);return r.stage===stage&&r.enemies.filter(e=>e.active).length>=6&&r;},45000);
   await keys([]);await key(120,200);
   s=await wait(async()=>{const r=await state();return r.bosshp>0&&r;});await save(`boss${stage}`,s);await shot(`boss${stage}`);
   const end=Date.now()+60000;
   while(Date.now()<end){
    s=await state();trace.push(s);if(s.mode===2){await save('pilot-trace',trace);throw Error('Pilot lost all life');}
    if(s.stage!==stage||s.mode===3)break;
    // Stage 2 needs four more hits after the bomb; use its invulnerability window.
    if(s.bosshp<=(stage===2?12:8)&&s.bombs>0){await keys([]);await key(120);continue;}
    const target=s.bossx+(s.bossdx>0?28:-28),want=['z'];
    if(s.y>190)want.push('ArrowUp');if(s.x<target-8)want.push('ArrowRight');if(s.x>target+8)want.push('ArrowLeft');
    await keys(want);await sleep(130);
   }
   await keys([]);assert(s.stage!==stage||s.mode===3,'Boss timeout');
  }
  s=await state();await save('play-trace',trace);await save('clear-state',s);assert.equal(s.mode,3);assert.equal(s.audio.bgm,4);assert.equal(s.audio.errors,0);
  await sleep(1000);await shot('clear');
  await capture('clear-bgm',()=>sleep(2200));
  await key(27);await wait(async()=>{const r=await call('status');return r.screen.width===768&&r.screen.height===512&&r;});
  await type('ECHO AUDIOEXITOK\n');
  const exit=await wait(async()=>{const r=await text();return r.lines.some(l=>l.trim().toUpperCase()==='AUDIOEXITOK')&&r;});
  await save('exit',exit);await shot('exit');
  const silence=await capture('exit-silence',()=>sleep(1200));assert(silence.acRms<0.001,'Sound still playing after exit');
  await type('PIRATE\n');
  const missing=await wait(async()=>{const r=await text();return r.lines.some(l=>l.includes('Z-MUSIC v2 required'))&&r;});
  await save('missing-driver',missing);await shot('missing-driver');
  await save('play-result',{result:'PASS',ramMB:2,clear:s,exit:true,driverReleased:true,missingDriverHandled:true});
  console.log('Audio release play PASS');
 }
}finally{if(browser)await browser.close();await client.close();}
