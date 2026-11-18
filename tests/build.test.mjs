import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import vm from 'node:vm';

const root=path.resolve(import.meta.dirname,'..'),dist=path.join(root,'dist');
const read=rel=>fs.readFile(path.join(dist,rel),'utf8');
const manifest=JSON.parse(await read('manifest.webmanifest'));
const info=JSON.parse(await read('build-info.json'));
const html=await read('index.html'),sw=await read('sw.js');
const bytes=new Map();
async function collect(dir){for(const entry of await fs.readdir(dir,{withFileTypes:true})){const file=path.join(dir,entry.name);if(entry.isDirectory())await collect(file);else bytes.set('/'+path.relative(dist,file).replaceAll('\\','/'),await fs.readFile(file));}}
await collect(dist);
function diskUrl(url){return url==='/'?'/index.html':url;}
function localResource(raw,base='/'){return new URL(raw,new URL(base,'https://example.test')).pathname;}
function assertCached(url){assert.ok(bytes.has(diskUrl(url)),`Missing packaged asset: ${url}`);assert.ok(info.offline.includes(url),`Asset omitted from offline list: ${url}`);}

test('installable manifest starts at the canonical root and icons have real PNG sizes',()=>{
  assert.equal(localResource(manifest.start_url),'/');
  assert.equal(localResource(manifest.scope),'/');
  assert.equal(manifest.display,'standalone');
  assert.equal(manifest.orientation,'landscape');
  assert.ok(manifest.icons.some(icon=>icon.purpose?.includes('maskable')));
  for(const icon of manifest.icons){
    const url=localResource(icon.src);assertCached(url);const buf=bytes.get(url);
    assert.equal(buf.subarray(1,4).toString(),'PNG');
    assert.equal(`${buf.readUInt32BE(16)}x${buf.readUInt32BE(20)}`,icon.sizes);
  }
});

test('offline list includes every build asset exactly once and uses / instead of /index.html',()=>{
  assert.ok(info.offline.includes('/'));
  assert.ok(!info.offline.includes('/index.html'),'Avoid Cloudflare index.html redirects during installation');
  assert.equal(new Set(info.offline).size,info.offline.length);
  assert.equal(info.assets,info.offline.length);
  for(const url of info.offline){assert.ok(url.startsWith('/')&&!url.startsWith('//'));assertCached(url);}
  for(const url of bytes.keys()){
    if(['/sw.js','/_headers','/build-info.json','/index.html'].includes(url))continue;
    assert.ok(info.offline.includes(url),`Uncached build file: ${url}`);
  }
  assertCached('/src/main.js');assertCached('/src/characters.js');assertCached('/src/world.js');assertCached('/vendor/three.module.js');assertCached('/vendor/three.core.js');
});

test('HTML, styles, manifest, and application imports resolve to local cached assets',()=>{
  for(const match of html.matchAll(/(?:src|href)=["']([^"']+)["']/g)){
    const raw=match[1];assert.ok(!/^(?:https?:)?\/\//.test(raw),`Remote page dependency: ${raw}`);assertCached(localResource(raw));
  }
  const importMap=JSON.parse(html.match(/<script type="importmap">([\s\S]+?)<\/script>/)[1]).imports;
  for(const [url,buf] of bytes){
    if(url.endsWith('.css'))for(const match of buf.toString().matchAll(/url\(\s*["']?([^\s'"\)]+)/g)){
      const raw=match[1];if(raw.startsWith('data:'))continue;
      assert.ok(!/^(?:https?:)?\/\//.test(raw),`Remote CSS resource: ${raw}`);assertCached(localResource(raw,url));
    }
    if(!url.startsWith('/src/')||!url.endsWith('.js'))continue;
    for(const match of buf.toString().matchAll(/\b(?:from\s*|import\s*\(\s*)['"]([^'"]+)['"]/g)){
      const raw=match[1];assert.ok(!/^https?:/.test(raw),`Remote JS dependency: ${raw}`);
      const resolved=raw.startsWith('.')||raw.startsWith('/')?localResource(raw,url):importMap[raw]&&localResource(importMap[raw]);
      assert.ok(resolved,`Unmapped browser dependency: ${raw}`);assertCached(resolved);
    }
  }
});

test('build version is a fingerprint of all cached payloads',()=>{
  const hash=crypto.createHash('sha256');
  const paths=[...bytes.keys()].filter(url=>!['/sw.js','/_headers','/build-info.json'].includes(url)).sort((a,b)=>path.join(dist,a.slice(1)).localeCompare(path.join(dist,b.slice(1)),'en'));
  // Match build.mjs native code-unit path ordering, independent of locale.
  paths.sort((a,b)=>path.join(dist,a.slice(1))<path.join(dist,b.slice(1))?-1:1);
  for(const url of paths)hash.update(bytes.get(url));
  assert.equal(hash.digest('hex').slice(0,12),info.version);
  assert.ok(sw.includes(`nathan2-${info.version}`));
});

function workerHarness(){
  const listeners=new Map(),stores=new Map(),origin='https://example.test';
  let offline=false,skipCalls=0,claimCalls=0;const networkRequests=[];
  const fetch=async request=>{const url=typeof request==='string'?request:request.url;networkRequests.push(url);if(offline)throw Error('Offline');const route=localResource(url);const buf=bytes.get(diskUrl(route));if(!buf)return new Response('Missing',{status:404});return new Response(buf,{status:200});};
  const caches={
    async open(name){if(!stores.has(name))stores.set(name,new Map());const store=stores.get(name);return{
      async addAll(urls){const pending=[];for(const url of urls){const response=await fetch(url);if(!response.ok)throw Error(`Precache failure: ${url}`);pending.push([localResource(url),response]);}for(const [url,response]of pending)store.set(url,response);},
      async match(url){const hit=store.get(localResource(typeof url==='string'?url:url.url));return hit?.clone();}
    };},
    async keys(){return [...stores.keys()];},async delete(name){return stores.delete(name);}
  };
  const self={location:{origin},clients:{claim:async()=>{claimCalls++;}},skipWaiting(){skipCalls++;},addEventListener(name,fn){listeners.set(name,fn);}};
  vm.runInNewContext(sw,{self,caches,fetch,URL});
  async function lifecycle(type){let waiting;listeners.get(type)({waitUntil(promise){waiting=promise;}});await waiting;}
  async function request(route,{mode='cors',method='GET',url=origin+route}={}){let result;listeners.get('fetch')({request:{url,mode,method},respondWith(promise){result=promise;}});return result?await result:null;}
  return{stores,listeners,networkRequests,lifecycle,request,setOffline(value){offline=value;},get skipCalls(){return skipCalls;},get claimCalls(){return claimCalls;}};
}

test('installed worker serves navigation and every required payload with the network unavailable',async()=>{
  const harness=workerHarness();await harness.lifecycle('install');
  assert.equal(harness.skipCalls,0,'Installing must not force an update during an active fight');
  const installRequests=harness.networkRequests.length;
  harness.setOffline(true);
  for(const route of info.offline){const response=await harness.request(route,{mode:route==='/'?'navigate':'cors'});assert.equal(response?.status,200,route);assert.ok((await response.arrayBuffer()).byteLength>0,route);}
  const navigation=await harness.request('/unloaded-route',{mode:'navigate'});assert.match(await navigation.text(),/NATHAN 2/);
  assert.equal(harness.networkRequests.length,installRequests,'Offline payloads must never fall back to network');
  assert.equal(await harness.request('/src/main.js',{method:'POST'}),null,'Non-GET requests are not intercepted');
  assert.equal(await harness.request('/asset.js',{url:'https://external.test/asset.js'}),null,'Other origins are not intercepted');
});

test('activation removes only stale second-game caches and update activation needs an explicit message',async()=>{
  const harness=workerHarness();harness.stores.set('nathan-first-game',new Map());harness.stores.set('nathan2-obsolete',new Map());harness.stores.set('other-app',new Map());await harness.lifecycle('install');
  harness.listeners.get('message')({data:'PING'});assert.equal(harness.skipCalls,0);
  await harness.lifecycle('activate');
  assert.ok(harness.stores.has('nathan-first-game'));assert.ok(harness.stores.has('other-app'));assert.ok(!harness.stores.has('nathan2-obsolete'));assert.equal(harness.claimCalls,1);
  harness.listeners.get('message')({data:'ACTIVATE_UPDATE'});assert.equal(harness.skipCalls,1);
  const main=bytes.get('/src/main.js').toString();assert.ok(!/postMessage\s*\(\s*['"]ACTIVATE_UPDATE/.test(main),'Page must not activate waiting updates automatically');
});

test('deployment excludes personal reference files, dependency directories, and original photo bytes',async t=>{
  for(const url of bytes.keys())assert.ok(!/(?:^|\/)(?:handoff|photos|references|node_modules|\.git|\.env)(?:\/|$)/i.test(url),`Private/source directory in build: ${url}`);
  let index;try{index=JSON.parse(await fs.readFile(path.join(root,'../handoff/package-index.json'),'utf8'));}catch(error){if(error.code==='ENOENT'){t.diagnostic('Private handoff is not present; hash comparison runs only in the local reference workspace.');return;}throw error;}
  const originalHashes=new Set([...index.photos.map(photo=>photo.sha256),index.concept.sha256]);
  assert.equal(originalHashes.size,13);
  for(const [url,buf]of bytes){const hash=crypto.createHash('sha256').update(buf).digest('hex');assert.ok(!originalHashes.has(hash),`Original personal reference would be published: ${url}`);}
});

test('publish inventory reports payload sizes and stays within the initial mobile download budget',t=>{
  const assets=info.offline.map(url=>({url,bytes:bytes.get(diskUrl(url)).length}));
  const total=assets.reduce((sum,asset)=>sum+asset.bytes,0);
  t.diagnostic(JSON.stringify({assets:assets.length,totalBytes:total,largest:assets.sort((a,b)=>b.bytes-a.bytes).slice(0,5)}));
  assert.ok(total<25*1024*1024,`Initial offline payload exceeds 25 MiB: ${total}`);
});
