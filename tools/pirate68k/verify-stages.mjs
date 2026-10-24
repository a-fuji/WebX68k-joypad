// Plays the real guest using keyboard events and MCP observations. No memory writes.
import assert from 'node:assert/strict';
import {post,key,shot,sleep,state,record,waitFor} from './verify-lib.mjs';
const evidence={time:new Date().toISOString(),stages:[],trace:[]};
const keyboard=keys=>post('keyboard',{keys});
await keyboard([]);await key(114,160);await sleep(700);
for(const stage of [1,2]){
 await keyboard([]);
 const six=await waitFor(async()=>{const s=await state();if(s.mode===2)throw new Error('Game over before boss');await keyboard(s.y>190?['ArrowUp']:[]);return s.stage===stage&&s.enemies.filter(e=>e.active).length>=6&&s;},45000);
 await keyboard([]);await key(120,200);
 let boss=await waitFor(async()=>{const s=await state();return s.bosshp>0&&s;});
 assert.equal(boss.stage,stage);assert(boss.kills>=6);
 console.log(`Stage ${stage}: boss HP ${boss.bosshp}, kills ${boss.kills}, life ${boss.life}`);
 await shot('boss-stage-'+stage);
 evidence.stages.push({stage,swarm:six,boss});
 const deadline=Date.now()+45000;
 while(Date.now()<deadline){
  const s=await state();evidence.trace.push(s);
  if(s.mode===2){await keyboard([]);await record('stages-failed',evidence);throw new Error('Pilot lost all life');}
  if(s.stage!==stage||s.mode===3){await keyboard([]);evidence.stages.at(-1).completed=s;break;}
  if(s.bosshp<=8&&s.bombs>0){await key(120,180);evidence.stages.at(-1).finishingBomb=await state();continue;}
  const keys=['z'];
  if(s.y>190)keys.push('ArrowUp');
  const target=s.bossx+(s.bossdx>0?28:-28);
  if(s.x<target-8)keys.push('ArrowRight');
  if(s.x>target+8)keys.push('ArrowLeft');
  await keyboard(keys);await sleep(180);
 }
 const s=await state();assert(s.stage!==stage||s.mode===3,'Boss did not fall');
 console.log(`Stage ${stage}: defeated, score ${s.score}, life ${s.life}`);
}
const clear=await state();assert.equal(clear.mode,3);assert.equal(clear.stage,2);
await shot('all-clear');await record('all-clear-state',clear);await record('stages',evidence);
console.log('PASS: both bosses defeated through real inputs');
