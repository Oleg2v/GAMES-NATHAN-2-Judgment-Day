import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,writeFile,readFile,readdir,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join,resolve,dirname} from 'node:path';
import {createHash} from 'node:crypto';
import {buildGodotSite,validatePackage,FILE_LIMIT} from '../scripts/build-godot.mjs';

async function fixture(t){
  const root=await mkdtemp(join(tmpdir(),'nathan2-package-test-'));
  t.after(async()=>{assert.equal(dirname(resolve(root)),resolve(tmpdir()));assert.ok(root.includes('nathan2-package-test-'));await rm(root,{recursive:true,force:true});});
  const source=join(root,'web-godot');await mkdir(source);
  const manifest={};const files={};
  for(const [name,type] of [['index.pck','application/octet-stream'],['index.wasm','application/wasm']]){
    const chunks=[];
    for(let index=0;index<2;index++){
      const bytes=Buffer.from(`${name} part ${index}`);
      const sha256=createHash('sha256').update(bytes).digest('hex');
      const file=`${name}.${index}.${sha256.slice(0,12)}.chunk`;
      files[file]=bytes;chunks.push({file,bytes:bytes.length,sha256});
    }
    manifest[name]={size:chunks.reduce((sum,chunk)=>sum+chunk.bytes,0),type,chunks};
  }
  Object.assign(files,{
    'index.html':'<!doctype html><html><head><link rel="manifest" href="manifest.webmanifest"></head><body><script src="transport.js"></script><script src="index.js"></script></body></html>',
    'index.js':'/* fixture engine shell */',
    'transport.js':`const manifest = ${JSON.stringify(manifest)};\nconst originalFetch = window.fetch.bind(window);`,
    'asset-manifest.json':JSON.stringify(manifest),
    'manifest.webmanifest':JSON.stringify({start_url:'./',scope:'./',display:'standalone',orientation:'landscape',icons:[{src:'icon-192.png'}]}),
    'icon-192.png':Buffer.from('fixture image bytes'),
    'sw.js':'/* fixture SW */',
    '_headers':'/sw.js\n  Cache-Control: no-cache\n'
  });
  const names=Object.keys(files);
  for(const [name,bytes] of Object.entries(files))await writeFile(join(source,name),bytes);
  await writeFile(join(source,'package-files.json'),JSON.stringify(names));
  return {root,source,names,manifest,files};
}

test('copies exactly allowlisted runtime and replaces stale dist without publishing source',async t=>{
  const f=await fixture(t);await mkdir(join(f.root,'dist'));await writeFile(join(f.root,'dist','old-source.js'),'old');
  await writeFile(join(f.source,'unlisted-photo.jpg'),'private fixture');
  await writeFile(join(f.source,'old.chunk'),'stale');
  const result=await buildGodotSite({root:f.root});
  assert.equal(result.files,f.names.length);
  assert.deepEqual((await readdir(join(f.root,'dist'))).sort(),[...f.names].sort());
  for(const name of f.names)assert.deepEqual(await readFile(join(f.root,'dist',name)),Buffer.from(f.files[name]));
});

test('rejects a corrupt chunk and preserves the previous valid dist',async t=>{
  const f=await fixture(t);await mkdir(join(f.root,'dist'));await writeFile(join(f.root,'dist','sentinel'),'keep');
  const chunk=f.manifest['index.pck'].chunks[0];await writeFile(join(f.source,chunk.file),Buffer.alloc(chunk.bytes));
  await assert.rejects(buildGodotSite({root:f.root}),/SHA-256 mismatch/);
  assert.equal(await readFile(join(f.root,'dist','sentinel'),'utf8'),'keep');
});

test('rejects incomplete chunk bytes',async t=>{
  const f=await fixture(t);await writeFile(join(f.source,f.names[0]),'x');
  await assert.rejects(validatePackage(f.source),/byte count mismatch/);
});

test('requires every chunk in the explicit allowlist',async t=>{
  const f=await fixture(t);await writeFile(join(f.source,'package-files.json'),JSON.stringify(f.names.slice(1)));
  await assert.rejects(validatePackage(f.source),/not allowlisted/);
});

test('rejects traversal and private source paths before reading them',async t=>{
  const f=await fixture(t);
  for(const name of ['../secret.jpg','/secret.jpg','C:/secret.jpg','photos/person.jpg','.godot/imported/private.ctex','nested\\secret.jpg']){
    await writeFile(join(f.source,'package-files.json'),JSON.stringify([...f.names,name]));
    await assert.rejects(validatePackage(f.source),/Unsafe package path|Non-runtime package path/);
  }
});

test('rejects duplicate allowlist records',async t=>{
  const f=await fixture(t);await writeFile(join(f.source,'package-files.json'),JSON.stringify([...f.names,f.names[0]]));
  await assert.rejects(validatePackage(f.source),/Duplicate package/);
});

test('rejects stale chunks accidentally added to the package allowlist',async t=>{
  const f=await fixture(t);await writeFile(join(f.source,'stale.chunk'),'old');await writeFile(join(f.source,'package-files.json'),JSON.stringify([...f.names,'stale.chunk']));
  await assert.rejects(validatePackage(f.source),/Unreferenced stale chunk/);
});

test('verifies reassembled payload length',async t=>{
  const f=await fixture(t);f.manifest['index.pck'].size++;await writeFile(join(f.source,'asset-manifest.json'),JSON.stringify(f.manifest));
  await assert.rejects(validatePackage(f.source),/Reassembled size mismatch/);
});

test('rejects a loader from a different export',async t=>{
  const f=await fixture(t);await writeFile(join(f.source,'transport.js'),'const manifest = {};\nconst originalFetch = window.fetch.bind(window);');
  await assert.rejects(validatePackage(f.source),/Transport and asset manifest disagree/);
});

test('requires local HTML dependencies and packaged PWA icons',async t=>{
  const f=await fixture(t);await writeFile(join(f.source,'index.html'),'<script src="https://cdn.example/engine.js"></script>');
  await assert.rejects(validatePackage(f.source),/Remote runtime dependency/);
  await writeFile(join(f.source,'index.html'),f.files['index.html']);
  const pwa=JSON.parse(f.files['manifest.webmanifest']);pwa.icons[0].src='missing.png';
  await writeFile(join(f.source,'manifest.webmanifest'),JSON.stringify(pwa));
  await assert.rejects(validatePackage(f.source),/PWA icon is not allowlisted/);
});

test('enforces per-file static host limit',async t=>{
  const f=await fixture(t);await writeFile(join(f.source,'index.js'),Buffer.alloc(FILE_LIMIT+1));
  await assert.rejects(validatePackage(f.source),/file limit exceeded/);
});
