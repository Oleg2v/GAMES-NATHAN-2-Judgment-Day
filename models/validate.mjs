import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { Vector3 } from 'three';
import { createCharacter, ANIMATION_STATES } from '../src/characters.js';

const results=[];
for (const kind of ['nathan','oz','enemy']) {
  const c=createCharacter(kind);
  assert.equal(c.mesh.type,'SkinnedMesh');
  assert.equal(c.skeleton.bones.length,27);
  c.root.position.set(3,2,-4);c.root.rotation.set(.1,.7,0);
  for (const state of ANIMATION_STATES) for(let i=0;i<=10;i++) {
    c.update(1/60,{state,time:i/10,phase:i/10,speed:1,slim:i/10,immediate:true});
    assert.deepEqual(c.root.position.toArray(),[3,2,-4]);
    assert.equal(c.root.rotation.y,.7);
    for(const bone of c.skeleton.bones) assert.ok(bone.matrixWorld.elements.every(Number.isFinite),`${kind}/${state}/${bone.name}`);
  }
  c.root.position.set(0,0,0);c.root.rotation.set(0,0,0);
  for(const state of ['idle','walk','run','carry','crouch','kick']) for(let i=0;i<=10;i++) {
    c.update(0,{state,time:i*.1,phase:i/10,speed:1,immediate:true});
    let low=Infinity;
    for(const side of ['left','right']) for(const z of [-.08,.22])low=Math.min(low,new Vector3(0,-.095,z).applyMatrix4(c.bones[`${side}Foot`].matrixWorld).y);
    assert.ok(Math.abs(low)<1e-5,`${kind}/${state}: supporting sole at ${low}`);
  }
  let bytes=await fs.readFile(new URL(`./exports/${kind}.glb`,import.meta.url));
  if(kind!=='enemy') {
    const jsonLength=bytes.readUInt32LE(12),data=JSON.parse(bytes.subarray(20,20+jsonLength).toString('utf8'));
    const view=data.bufferViews[data.images[0].bufferView],binStart=20+jsonLength+8;
    const png=bytes.subarray(binStart+view.byteOffset,binStart+view.byteOffset+view.byteLength);
    const source=await fs.readFile(new URL('../public/assets/face-atlas.png',import.meta.url));
    assert.ok(png.equals(source),'GLB embeds the exact generated PNG');
    assert.equal(png.subarray(1,4).toString(),'PNG');
    assert.ok(data.materials.some(m=>m.name==='painted face albedo'&&m.pbrMetallicRoughness.baseColorTexture?.index===0));
    // Node has no DOM image decoder. Re-import rig/geometry independently after
    // checking texture bytes and material binding above; visual QA is in-browser.
    for(const m of data.materials)if(m.pbrMetallicRoughness)delete m.pbrMetallicRoughness.baseColorTexture;
    const raw=Buffer.from(JSON.stringify(data)),json=Buffer.alloc((raw.length+3)&~3,32);raw.copy(json);
    const binary=bytes.subarray(20+jsonLength),out=Buffer.alloc(20+json.length+binary.length);
    bytes.copy(out,0,0,12);out.writeUInt32LE(out.length,8);out.writeUInt32LE(json.length,12);out.writeUInt32LE(0x4e4f534a,16);json.copy(out,20);binary.copy(out,20+json.length);bytes=out;
  }
  const gltf=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
  assert.equal(gltf.animations.length,ANIMATION_STATES.length);
  let skinned=0;gltf.scene.traverse(o=>{if(o.isSkinnedMesh){skinned++;assert.equal(o.skeleton.bones.length,27)}});
  assert.ok(skinned>0);
  results.push({kind,states:ANIMATION_STATES.length,triangles:c.metadata.triangles,exportAnimations:gltf.animations.length,skinnedPrimitives:skinned});
  c.dispose();
}
console.log(JSON.stringify({passed:true,characters:results},null,2));
