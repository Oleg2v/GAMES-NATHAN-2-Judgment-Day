import assert from 'node:assert/strict';
import {Vector3} from 'three';
import {createCharacter} from '../src/characters.js';

const p=createCharacter('nathan'),v=createCharacter('enemy'),results=[];
for(const scale of [.9,.96,1.04]) {
  const phase=.586;
  p.root.position.set(.86,0,-.24);p.root.rotation.set(0,Math.PI,0);
  v.root.scale.setScalar(scale);v.root.position.set(.28,Math.sin(phase*Math.PI)*.15,.17);v.root.rotation.set(-Math.sin(phase*Math.PI)*.87,Math.PI,0);
  p.update(0,{state:'envSlam',phase,immediate:true});v.update(0,{state:'envVictim',phase,immediate:true});
  p.bones.spine.rotation.set(.9,0,-.2);p.root.updateMatrixWorld(true);
  const head=v.bones.head.localToWorld(new Vector3(-.07,.10,-.14)),back=v.bones.chest.localToWorld(new Vector3(-.25,.17,-.12));
  const right=p.placeHand('right',head),left=p.placeHand('left',back);
  assert.ok(right<.095&&left<.075,`Contact outside palm/finger reach: ${scale}, ${right}, ${left}`);
  assert.deepEqual(p.root.position.toArray(),[.86,0,-.24]);
  results.push({victimScale:scale,rightPalmToHeadM:+right.toFixed(4),leftPalmToBackM:+left.toFixed(4)});
}
p.dispose();v.dispose();console.log(JSON.stringify({passed:true,results},null,2));
