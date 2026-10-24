import {writeFile,readFile} from 'node:fs/promises';
export const sleep=ms=>new Promise(r=>setTimeout(r,ms));
export async function post(route,q={}){
 const r=await fetch('http://127.0.0.1:5399/'+route,{method:'POST',body:JSON.stringify(q)});
 const body=await r.text();if(!r.ok)throw new Error(body);return JSON.parse(body);
}
export async function call(name,args={}){
 const r=await post('call',{name,args});return JSON.parse(r.content[0].text);
}
export const key=(code,ms=150)=>call('key_sequence',{steps:[{code,ms}]});
export const type=text=>call('type_text',{text});
export const shot=name=>post('shot',{name});
export function decodeState(bytes,addr){
 const b=Buffer.from(bytes);
 return {addr,magic:b.subarray(0,8).toString(),mode:b.readUInt16BE(8),stage:b.readUInt16BE(10),x:b.readUInt16BE(12),y:b.readUInt16BE(14),score:b.readUInt32BE(16),kills:b.readUInt16BE(20),life:b.readUInt16BE(22),bombs:b.readUInt16BE(24),frame:b.readUInt32BE(28),keys:b.readUInt16BE(32),shots:b.readUInt16BE(36),bombsused:b.readUInt16BE(38),bosshp:b.readInt16BE(40),bossx:b.readUInt16BE(42),bossdx:b.readInt16BE(44),invul:b.readUInt16BE(46),musicstep:b.readUInt16BE(66),xspactive:b.readUInt16BE(68),spritecount:b.readUInt16BE(70),spritepeak:b.readUInt16BE(72),videostage:b.readUInt16BE(74),enemies:Array.from({length:8},(_,i)=>({active:b.readUInt16BE(80+8*i),x:b.readUInt16BE(82+8*i),y:b.readUInt16BE(84+8*i)}))};
}
let addr;
export async function state(){
 if(addr==null){
  const candidates=[];
  for(let a=0x20000;a<0x120000;a+=65536){
   const {bytes}=await call('read_memory',{addr:a,length:65536});
   const b=Buffer.from(bytes);
   for(let i=b.indexOf('P68KSTAT');i>=0;i=b.indexOf('P68KSTAT',i+8)){
    if(i+272<=b.length)candidates.push(decodeState(b.subarray(i,i+272),a+i));
   }
  }
  let saved;try{saved=JSON.parse(await readFile('_local/pirate68k/state-address.json')).addr;}catch{}
  const title=candidates.filter(s=>s.mode===0&&s.stage===0);
  addr=(title.at(-1)||candidates.find(s=>s.addr===saved)||candidates.at(-1))?.addr;
  if(addr==null)throw new Error('P68KSTAT absent');
  await writeFile('_local/pirate68k/state-address.json',JSON.stringify({addr}));
 }
 const {bytes}=await call('read_memory',{addr,length:272});
 const s=decodeState(bytes,addr);if(s.magic!=='P68KSTAT')throw new Error('Invalid state marker');return s;
}
export async function waitFor(fn,timeout=20000){
 const end=Date.now()+timeout;let last;
 do{last=await fn();if(last)return last;await sleep(200);}while(Date.now()<end);
 throw new Error('Timed out waiting for guest state');
}
export async function record(name,value){
 await writeFile('_local/pirate68k/'+name+'.json',JSON.stringify(value,null,2)+'\n');
}
