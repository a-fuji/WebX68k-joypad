import assert from 'node:assert/strict';
import {post,call,key,shot,sleep,state,record,waitFor} from './verify-lib.mjs';
const evidence={time:new Date().toISOString(),checks:[]};
const check=(name,detail)=>{evidence.checks.push({name,...detail});console.log(JSON.stringify({name,...detail}));};
const keyboard=keys=>post('keyboard',{keys});
let s=await state();assert.equal(s.mode,0);check('title',{state:s});
await key(122,160);
s=await waitFor(async()=>{const r=await state();return r.mode===1&&r;});assert.equal(s.stage,1);check('start',{state:s});
const before=s;await key(275,350);s=await state();assert(s.x>before.x);check('MCP right movement',{before,after:s});
await key(114,160);await waitFor(async()=>{const r=await state();return r.life===3&&r.frame>=3&&r.frame<30&&r;});
// All eight directions use normal browser key events, including simultaneous diagonals.
for(const keys of [['ArrowUp'],['ArrowDown'],['ArrowLeft'],['ArrowRight'],['ArrowUp','ArrowLeft'],['ArrowUp','ArrowRight'],['ArrowDown','ArrowLeft'],['ArrowDown','ArrowRight']]){
 const a=await state();await keyboard(keys);await sleep(180);await keyboard([]);const b=await state();
 check('direction',{keys,before:a,after:b});
 for(const [k,delta] of [['ArrowUp',b.y-a.y],['ArrowDown',b.y-a.y],['ArrowLeft',b.x-a.x],['ArrowRight',b.x-a.x]]){
  if(keys.includes(k))assert(k==='ArrowUp'||k==='ArrowLeft'?delta<0:delta>0,`${k}: delta=${delta}`);
 }
}
await key(114,160);await waitFor(async()=>{const r=await state();return r.life===3&&r.frame>=3&&r.frame<30&&r;});
const a=await state();await key(122,600);const b=await state();assert(b.shots>a.shots);check('MCP shot',{before:a,after:b});
await key(114,160);await waitFor(async()=>{const r=await state();return r.life===3&&r.frame>=3&&r.frame<30&&r;});
await waitFor(async()=>{const r=await state();return r.enemies.filter(e=>e.active).length>=3&&r;},20000);
const bombBefore=await state();await key(120,200);const bombAfter=await state();
assert.equal(bombAfter.bombs,bombBefore.bombs-1);assert(bombAfter.score>bombBefore.score);assert(bombAfter.kills>=3);check('MCP bomb',{before:bombBefore,after:bombAfter});await record('bomb-state',bombAfter);await shot('bomb');
await key(114,160);await waitFor(async()=>{const r=await state();return r.life===3&&r.frame>=3&&r.frame<30&&r;});
// No input: missed enemies reduce life and eventually end the game.
const over=await waitFor(async()=>{const r=await state();return r.mode===2&&r;},90000);
assert.equal(over.life,0);check('game over',{state:over});await shot('game-over');
await key(122,160);s=await waitFor(async()=>{const r=await state();return r.mode===1&&r.life===3&&r;});assert.equal(s.life,3);assert.equal(s.score,0);check('restart',{state:s});
await record('game-checks',evidence);
console.log('Basic game checks PASS; ready for two-stage pilot');
