import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { GLTFExporter } from 'three/addons/exporters/GLTFExporter.js';
import { createCharacter, createAnimationClips } from '../src/characters.js';

// GLTFExporter uses FileReader for generated binary buffers. No DOM, canvas,
// texture or image input is needed for these original geometric models.
globalThis.FileReader ??= class FileReader {
  readAsArrayBuffer(blob) {
    blob.arrayBuffer().then(result => { this.result = result; this.onload?.(); this.onloadend?.(); });
  }
  readAsDataURL(blob) {
    blob.arrayBuffer().then(result => { this.result = `data:${blob.type || 'application/octet-stream'};base64,${Buffer.from(result).toString('base64')}`; this.onload?.(); this.onloadend?.(); });
  }
};

const directory = path.dirname(fileURLToPath(import.meta.url));
const atlas = await fs.readFile(path.join(directory, '../public/assets/face-atlas.png'));
function embedAtlas(arrayBuffer) {
  const original = Buffer.from(arrayBuffer), jsonLength = original.readUInt32LE(12);
  const gltf = JSON.parse(original.subarray(20, 20 + jsonLength).toString('utf8'));
  const binOffset = 20 + jsonLength, binLength = original.readUInt32LE(binOffset);
  const binary = original.subarray(binOffset + 8, binOffset + 8 + binLength);
  const imageOffset = (binary.length + 3) & ~3, combined = Buffer.alloc((imageOffset + atlas.length + 3) & ~3);
  binary.copy(combined); atlas.copy(combined, imageOffset);
  const imageView = gltf.bufferViews.length;
  gltf.bufferViews.push({buffer:0,byteOffset:imageOffset,byteLength:atlas.length});
  gltf.images=[{name:'Original painted Nathan/Oz atlas',mimeType:'image/png',bufferView:imageView}];
  gltf.samplers=[{magFilter:9729,minFilter:9987,wrapS:33071,wrapT:33071}];
  gltf.textures=[{sampler:0,source:0}];gltf.buffers[0].byteLength=combined.length;
  for(const m of gltf.materials)if(m.name==='painted face albedo')m.pbrMetallicRoughness.baseColorTexture={index:0,texCoord:0};
  const rawJSON=Buffer.from(JSON.stringify(gltf)), json=Buffer.alloc((rawJSON.length+3)&~3,32);rawJSON.copy(json);
  const out=Buffer.alloc(12+8+json.length+8+combined.length);
  out.writeUInt32LE(0x46546c67,0);out.writeUInt32LE(2,4);out.writeUInt32LE(out.length,8);
  out.writeUInt32LE(json.length,12);out.writeUInt32LE(0x4e4f534a,16);json.copy(out,20);
  const next=20+json.length;out.writeUInt32LE(combined.length,next);out.writeUInt32LE(0x004e4942,next+4);combined.copy(out,next+8);
  return out;
}
const report = [];
await fs.mkdir(path.join(directory, 'exports'), { recursive: true });
for (const kind of ['nathan', 'oz', 'enemy']) {
  const c = createCharacter(kind);
  // glTF's image origin is top-left. Runtime TextureLoader flips the bitmap;
  // exported PNG stays unmodified, so flip texture V in this export instance.
  if (kind !== 'enemy') {
    const uv = c.mesh.geometry.getAttribute('uv');
    for (let i = 0; i < uv.count; i++) uv.setY(i, 1 - uv.getY(i));
  }
  const animations = createAnimationClips(c);
  c.root.animations = animations;
  const exporter = new GLTFExporter();
  let glb = Buffer.from(await exporter.parseAsync(c.root, { binary: true, animations, onlyVisible: true }));
  if (kind !== 'enemy') glb = embedAtlas(glb);
  const out = path.join(directory, 'exports', `${kind}.glb`);
  await fs.writeFile(out, Buffer.from(glb));
  const sceneJSON = c.root.toJSON();
  if (kind !== 'enemy') {
    const imageUUID = 'face-atlas-generated-image', textureUUID = 'face-atlas-generated-texture';
    sceneJSON.images = [{uuid:imageUUID,url:`data:image/png;base64,${atlas.toString('base64')}`}];
    sceneJSON.textures = [{uuid:textureUUID,name:'Original painted face atlas',image:imageUUID,mapping:300,channel:0,repeat:[1,1],offset:[0,0],center:[0,0],rotation:0,wrap:[1001,1001],format:1023,internalFormat:null,type:1009,colorSpace:'srgb',minFilter:1008,magFilter:1006,anisotropy:4,flipY:false,generateMipmaps:true,premultiplyAlpha:false,unpackAlignment:4}];
    for (const m of sceneJSON.materials) if (m.name === 'painted face albedo') m.map = textureUUID;
  }
  await fs.writeFile(path.join(directory, 'exports', `${kind}.scene.json`), JSON.stringify(sceneJSON));
  report.push({ ...c.metadata, animationClips: animations.length, glbBytes: glb.byteLength });
  c.dispose();
}
await fs.writeFile(path.join(directory, 'exports', 'manifest.json'), JSON.stringify({ format: 'glTF 2.0', generatedFrom: 'src/characters.js', characters: report }, null, 2));
console.log(JSON.stringify(report, null, 2));
