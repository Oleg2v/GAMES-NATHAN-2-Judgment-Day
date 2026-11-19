import {readFile,writeFile,mkdir,lstat,realpath,rename,rm} from 'node:fs/promises';
import {createHash,randomUUID} from 'node:crypto';
import {resolve,join,dirname,relative,isAbsolute,sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {isDeepStrictEqual} from 'node:util';

const here=dirname(fileURLToPath(import.meta.url));
const sha256=bytes=>createHash('sha256').update(bytes).digest('hex');
export const FILE_LIMIT=20_000_000;
const required=['index.html','index.js','transport.js','asset-manifest.json','manifest.webmanifest','sw.js','_headers'];

function safeName(value){
  if(typeof value!=='string'||!value||value.includes('\\')||/[\x00-\x1f%?#:]/.test(value)||isAbsolute(value)||value.split('/').some(part=>!part||part==='.'||part==='..'||part.startsWith('.')))
    throw new Error(`Unsafe package path: ${JSON.stringify(value)}`);
  if(value.split('/').some(part=>/^(?:photos?|references?|handoff|work|node_modules|godot|src|scripts|tests|cache)$/i.test(part)))
    throw new Error(`Non-runtime package path: ${value}`);
  return value;
}

async function regularFile(root,name){
  safeName(name);
  let at=root;
  const parts=name.split('/');
  for(let i=0;i<parts.length;i++){
    at=join(at,parts[i]);
    const info=await lstat(at);
    if(info.isSymbolicLink()||!(i===parts.length-1?info.isFile():info.isDirectory()))
      throw new Error(`Package path is not a regular file: ${name}`);
  }
  return readFile(at);
}

/** Validate the frozen package before copying anything into the publish tree. */
export async function validatePackage(directory){
  const source=resolve(directory);
  const rootInfo=await lstat(source);
  if(rootInfo.isSymbolicLink()||!rootInfo.isDirectory())throw new Error('Package root must be a real directory');
  const names=JSON.parse(await regularFile(source,'package-files.json'));
  if(!Array.isArray(names)||!names.length)throw new Error('package-files.json must be a nonempty filename array');
  for(const name of names)safeName(name);
  if(new Set(names).size!==names.length)throw new Error('Duplicate package filenames');
  const allowed=new Set(names);
  for(const name of required)if(!allowed.has(name))throw new Error(`Required runtime file is not allowlisted: ${name}`);
  const files=[];
  const textFiles={};
  for(const name of names){
    const bytes=await regularFile(source,name);
    if(bytes.length>FILE_LIMIT)throw new Error(`Static-host file limit exceeded: ${name}`);
    files.push({name,bytes:bytes.length,sha256:sha256(bytes)});
    if(['asset-manifest.json','transport.js','manifest.webmanifest','index.html'].includes(name))textFiles[name]=bytes.toString('utf8');
  }
  const manifest=JSON.parse(textFiles['asset-manifest.json']);
  if(!manifest||Array.isArray(manifest)||typeof manifest!=='object')throw new Error('Invalid asset manifest');
  const hashes=new Map(files.map(file=>[file.name,file]));
  const usedChunks=new Set();
  for(const [name,entry] of Object.entries(manifest)){
    safeName(name);
    if(allowed.has(name))throw new Error(`Split virtual file must not coexist with a raw file: ${name}`);
    if(!Number.isSafeInteger(entry.size)||entry.size<=0||!Array.isArray(entry.chunks)||!entry.chunks.length)
      throw new Error(`Invalid split file metadata: ${name}`);
    if(!['application/wasm','application/octet-stream'].includes(entry.type))throw new Error(`Invalid content type: ${name}`);
    let total=0;
    for(const chunk of entry.chunks){
      safeName(chunk.file);
      if(!allowed.has(chunk.file)||!chunk.file.endsWith('.chunk'))throw new Error(`Chunk is not allowlisted: ${chunk.file}`);
      if(usedChunks.has(chunk.file))throw new Error(`Duplicate chunk reference: ${chunk.file}`);
      usedChunks.add(chunk.file);
      const file=hashes.get(chunk.file);
      if(!Number.isSafeInteger(chunk.bytes)||chunk.bytes<=0||file.bytes!==chunk.bytes)throw new Error(`Chunk byte count mismatch: ${chunk.file}`);
      if(!/^[a-f0-9]{64}$/.test(chunk.sha256)||file.sha256!==chunk.sha256)throw new Error(`Chunk SHA-256 mismatch: ${chunk.file}`);
      total+=chunk.bytes;
    }
    if(total!==entry.size)throw new Error(`Reassembled size mismatch: ${name}`);
  }
  for(const name of names)if(name.endsWith('.chunk')&&!usedChunks.has(name))throw new Error(`Unreferenced stale chunk is allowlisted: ${name}`);
  for(const name of ['index.pck','index.wasm'])if(!allowed.has(name)&&!Object.hasOwn(manifest,name))throw new Error(`Missing Godot payload: ${name}`);
  const embedded=textFiles['transport.js'].match(/const manifest\s*=\s*(\{[\s\S]*?\});\s*\n\s*const originalFetch/);
  if(!embedded||!isDeepStrictEqual(JSON.parse(embedded[1]),manifest))throw new Error('Transport and asset manifest disagree');
  const app=JSON.parse(textFiles['manifest.webmanifest']);
  if(app.start_url!=='./'||app.scope!=='./'||app.display!=='standalone'||app.orientation!=='landscape')throw new Error('PWA must use local landscape standalone scope');
  if(!Array.isArray(app.icons)||!app.icons.length)throw new Error('PWA icons are missing');
  for(const icon of app.icons)if(!allowed.has(safeName(icon.src)))throw new Error(`PWA icon is not allowlisted: ${icon.src}`);
  for(const match of textFiles['index.html'].matchAll(/<(?:script|link|img)\b[^>]*?\b(?:src|href)=["']([^"']+)["']/g)){
    const url=match[1];
    if(url.startsWith('data:')||url.startsWith('#'))continue;
    if(/^(?:https?:|\/\/)/i.test(url))throw new Error(`Remote runtime dependency: ${url}`);
    const file=url.replace(/^\.\//,'').split(/[?#]/)[0];
    if(!allowed.has(safeName(file)))throw new Error(`HTML asset is not allowlisted: ${file}`);
  }
  return {source,files,splitFiles:Object.keys(manifest),bytes:files.reduce((sum,file)=>sum+file.bytes,0)};
}

async function existing(path){try{return await lstat(path);}catch(error){if(error.code==='ENOENT')return null;throw error;}}

/** Replace only <repo>/dist after validation; stale previous-game files cannot survive. */
export async function buildGodotSite({root=resolve(here,'..')}={}){
  root=await realpath(resolve(root));
  const report=await validatePackage(join(root,'web-godot'));
  const output=join(root,'dist');
  const suffix=`${process.pid}-${randomUUID()}`;
  const stage=join(root,`.dist-godot-stage-${suffix}`);
  const backup=join(root,`.dist-godot-backup-${suffix}`);
  for(const path of [output,stage,backup]){
    if(dirname(path)!==root||relative(root,path).includes(sep))throw new Error('Unsafe build target');
    const info=await existing(path);
    if(info&&(info.isSymbolicLink()||!info.isDirectory()))throw new Error(`Build target is not a directory: ${path}`);
  }
  let backedUp=false;
  try{
    await mkdir(stage);
    for(const file of report.files){
      const bytes=await regularFile(report.source,file.name);
      if(sha256(bytes)!==file.sha256)throw new Error(`Package changed during build: ${file.name}`);
      await mkdir(dirname(join(stage,file.name)),{recursive:true});
      await writeFile(join(stage,file.name),bytes,{flag:'wx'});
    }
    if(await existing(output)){await rename(output,backup);backedUp=true;}
    try{await rename(stage,output);}catch(error){if(backedUp){await rename(backup,output);backedUp=false;}throw error;}
    if(backedUp){await rm(backup,{recursive:true});backedUp=false;}
  }finally{
    if(await existing(stage))await rm(stage,{recursive:true});
  }
  return {output,files:report.files.length,bytes:report.bytes,splitFiles:report.splitFiles};
}

if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  try{
    const args=process.argv.slice(2);
    if(args[0]==='--verify'&&args.length===2){
      const report=await validatePackage(args[1]);
      console.log(JSON.stringify({source:report.source,files:report.files.length,bytes:report.bytes,splitFiles:report.splitFiles,verified:true}));
    }else if(args.length===0||(args[0]==='--root'&&args.length===2)){
      console.log(JSON.stringify(await buildGodotSite(args.length?{root:args[1]}:{})));
    }else throw new Error('Usage: node build-godot.mjs [--root <repo> | --verify <package>]');
  }catch(error){console.error(error.message);process.exitCode=1;}
}
