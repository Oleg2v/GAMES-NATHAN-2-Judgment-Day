import { mkdir, readFile, writeFile, readdir, stat, copyFile } from 'node:fs/promises';
import { resolve, join, relative } from 'node:path';
import { createHash } from 'node:crypto';

const argument = name => { const index=process.argv.indexOf(name); return index<0 ? null : process.argv[index+1]; };
const source = argument('--source') ? resolve(argument('--source')) : resolve(import.meta.dirname, '../../godot-web');
const target = argument('--target') ? resolve(argument('--target')) : resolve(import.meta.dirname, '../../godot-web-packaged');
const iconRoot = argument('--icons') ? resolve(argument('--icons')) : resolve(import.meta.dirname,'../../../game/public');
const noticesRoot = argument('--notices') ? resolve(argument('--notices')) : resolve(import.meta.dirname,'../../../game-godot/assets/licenses');
const limit = 20_000_000;
await mkdir(target, { recursive: true });
const manifest = {};
const currentFiles = new Set(['index.html', 'transport.js', 'manifest.webmanifest', 'icon-192.png', 'icon-512.png']);
let notices = 'NATHAN 2: JUDGMENT DAY — CREDITS AND LICENSES\n\n';
for (const name of (await readdir(noticesRoot)).sort()) {
  if (name.endsWith('.txt') || name.endsWith('.md')) notices += `\n\n${name}\n${await readFile(join(noticesRoot,name),'utf8')}`;
}
await writeFile(join(target,'credits.txt'),notices.split('\n').map(line=>line.trimEnd()).join('\n').trimEnd()+'\n');
currentFiles.add('credits.txt');
const files = await readdir(source);
for (const name of files) {
  const path = join(source, name);
  if (!(await stat(path)).isFile()) continue;
  const data = await readFile(path);
  if (data.length < limit) {
    await writeFile(join(target, name), data);
    currentFiles.add(name);
    continue;
  }
  const entry = { size: data.length, type: name.endsWith('.wasm') ? 'application/wasm' : 'application/octet-stream', chunks: [] };
  for (let offset = 0; offset < data.length; offset += limit) {
    const bytes = data.subarray(offset, Math.min(offset + limit, data.length));
    const hash = createHash('sha256').update(bytes).digest('hex');
    const chunkName = `${name}.${String(entry.chunks.length).padStart(2, '0')}.${hash.slice(0, 12)}.chunk`;
    await writeFile(join(target, chunkName), bytes);
    entry.chunks.push({ file: chunkName, bytes: bytes.length, sha256: hash });
    currentFiles.add(chunkName);
  }
  manifest[name] = entry;
}
const loader = `/* Generated transport for static hosts with a per-file size limit. */
(() => {
  const manifest = ${JSON.stringify(manifest)};
  const originalFetch = window.fetch.bind(window);
  const root = new URL('.', document.currentScript.src);
  window.fetch = async (input, options) => {
    const url = new URL(typeof input === 'string' || input instanceof URL ? input : input.url, location.href);
    const name = url.href.startsWith(root.href) ? url.pathname.slice(root.pathname.length) : '';
    const entry = url.origin === root.origin ? manifest[name] : null;
    if (!entry) return originalFetch(input, options);
    let index = 0;
    const stream = new ReadableStream({
      async pull(controller) {
        if (index >= entry.chunks.length) { controller.close(); return; }
        try {
          const chunk = entry.chunks[index++];
          const response = await originalFetch(new URL(chunk.file, root), options);
          if (!response.ok) throw new Error('Не удалось загрузить часть игры: HTTP ' + response.status);
          const buffer = await response.arrayBuffer();
          if (buffer.byteLength !== chunk.bytes) throw new Error('Неполная загрузка игры. Обновите страницу.');
          const hash = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', buffer)), b => b.toString(16).padStart(2, '0')).join('');
          if (hash !== chunk.sha256) throw new Error('Ошибка проверки файла игры. Обновите страницу.');
          controller.enqueue(new Uint8Array(buffer));
        } catch (error) { controller.error(error); }
      }
    });
    return new Response(stream, {status: 200, headers: {'Content-Type': entry.type, 'Content-Length': String(entry.size)}});
  };
})();
`;
await writeFile(join(target, 'transport.js'), loader);
await writeFile(join(target, 'asset-manifest.json'), JSON.stringify(manifest, null, 2));
let html = await readFile(join(source, 'index.html'), 'utf8');
html = html.replace('<script src="index.js"></script>', '<script src="transport.js"></script>\n<script src="index.js"></script>');
if (!html.includes('src="transport.js"')) throw new Error('Export shell script tag changed; transport was not injected.');
html = html.replace('<html lang="en">', '<html lang="ru">')
 .replace('width=device-width, user-scalable=no, initial-scale=1.0', 'width=device-width, initial-scale=1.0, viewport-fit=cover')
 .replace(/<img id="status-splash"[^>]*>/, '<div id="status-splash"><strong>NATHAN<span>2</span></strong><small>JUDGMENT DAY</small><p>Ашдод ждёт.</p></div>')
 .replace('</head>', `<meta name="theme-color" content="#101c21"><meta name="apple-mobile-web-app-capable" content="yes"><link rel="manifest" href="manifest.webmanifest"><style>
body{background:#101c21;-webkit-user-select:none;user-select:none;overscroll-behavior:none}#status{background:radial-gradient(ellipse at 75% 20%,#23404a,#101c21 65%);font-family:Arial,sans-serif}#status-splash{position:relative;text-align:center;inset:auto;margin:0}#status-splash strong{font-size:clamp(48px,10vw,112px);letter-spacing:-.065em;color:#f1eedf}#status-splash span{color:#f576a2}#status-splash small{display:block;letter-spacing:.35em;color:#c2d0ce;margin-top:8px}#status-splash p{font-size:13px;color:#9db2b6;margin-top:32px}#status-progress{height:4px;appearance:none;accent-color:#f576a2}#status-progress::-webkit-progress-bar{background:#31454b}#status-progress::-webkit-progress-value{background:#f576a2}#install-game{position:fixed;bottom:max(12px,env(safe-area-inset-bottom));right:18px;border:1px solid #65797c;background:#14232bbd;color:#eee9df;border-radius:3px;padding:9px 12px;font-size:11px;z-index:20;display:none}
#install-game[hidden]{display:none!important}
#credits{position:fixed;bottom:10px;left:18px;color:#b7c3bf;font:11px Arial,sans-serif;z-index:21;text-decoration:none}body[data-playing="true"] #credits{display:none}
</style></head>`)
 .replace('</body>', `<a id="credits" href="credits.txt" target="_blank" rel="noopener">Лицензии</a><button id="install-game" type="button">↗ Установить</button><script>
const installButton=document.getElementById('install-game');let installPrompt=null;
const installLabels={ru:'↗ Установить',en:'↗ Install',he:'↗ התקנה'};
const installHelp={ru:'iPhone: Поделиться → На экран Домой.',en:'iPhone: Share → Add to Home Screen.',he:'iPhone: שיתוף ← הוספה למסך הבית.'};
function syncInstall(){const language=document.body.dataset.lang||'ru';installButton.textContent=installLabels[language]||installLabels.ru;installButton.hidden=document.body.dataset.playing==='true';document.getElementById('credits').textContent=({ru:'Лицензии',en:'Credits',he:'רישיונות'})[language]||'Credits'}
new MutationObserver(syncInstall).observe(document.body,{attributes:true,attributeFilter:['data-playing','data-lang']});syncInstall();
window.addEventListener('beforeinstallprompt',event=>{event.preventDefault();installPrompt=event;installButton.style.display='block'});
installButton.addEventListener('click',async()=>{if(installPrompt){await installPrompt.prompt();installPrompt=null;installButton.style.display='none'}else{alert(installHelp[document.body.dataset.lang]||installHelp.ru)}});
if(/iPad|iPhone|iPod/.test(navigator.userAgent)&&!navigator.standalone){installButton.style.display='block'}
document.getElementById('canvas').addEventListener('contextmenu',event=>event.preventDefault());
if('serviceWorker' in navigator){navigator.serviceWorker.register('sw.js').then(reg=>{reg.addEventListener('updatefound',()=>{const worker=reg.installing;if(worker)worker.addEventListener('statechange',()=>{if(worker.state==='activated')document.documentElement.dataset.offline='ready'})});if(reg.active)document.documentElement.dataset.offline='ready'}).catch(()=>{document.documentElement.dataset.offline='unavailable'})}
</script></body>`);
html=html.trimEnd()+'\n';
await writeFile(join(target, 'index.html'), html);
for (const name of ['icon-192.png','icon-512.png']) await copyFile(join(iconRoot,name),join(target,name));
await writeFile(join(target, 'manifest.webmanifest'), JSON.stringify({name:'NATHAN 2: Judgment Day',short_name:'NATHAN 2',start_url:'./',scope:'./',display:'standalone',orientation:'landscape',background_color:'#101c21',theme_color:'#101c21',icons:[{src:'icon-192.png',sizes:'192x192',type:'image/png'},{src:'icon-512.png',sizes:'512x512',type:'image/png'}]},null,2));
const version=createHash('sha256').update(JSON.stringify(manifest)).update(html).digest('hex').slice(0,12);
await writeFile(join(target,'sw.js'), `const CACHE='nathan2-godot-${version}';const ASSETS=${JSON.stringify([...currentFiles])};
self.addEventListener('install',event=>event.waitUntil((async()=>{const cache=await caches.open(CACHE);await cache.addAll(ASSETS)})()));
self.addEventListener('activate',event=>event.waitUntil((async()=>{for(const name of await caches.keys()){if(name.startsWith('nathan2-')&&name!==CACHE)await caches.delete(name)}await self.clients.claim()})()));
self.addEventListener('fetch',event=>{if(event.request.method!=='GET'||new URL(event.request.url).origin!==location.origin)return;event.respondWith((async()=>{const cache=await caches.open(CACHE);const hit=await cache.match(event.request.mode==='navigate'?'index.html':event.request,{ignoreSearch:true});if(hit)return hit;return fetch(event.request)})())});
`);
currentFiles.add('sw.js');currentFiles.add('asset-manifest.json');currentFiles.add('_headers');
await writeFile(join(target,'package-files.json'),JSON.stringify([...currentFiles].sort(),null,2));
await writeFile(join(target, '_headers'), '/\n  Cache-Control: no-cache\n/index.html\n  Cache-Control: no-cache\n/asset-manifest.json\n  Cache-Control: no-cache\n/*.chunk\n  Cache-Control: public, max-age=31536000, immutable\n');
// Verify every emitted chunk against the source before reporting a usable package.
for (const [name, entry] of Object.entries(manifest)) {
  const buffers = await Promise.all(entry.chunks.map(chunk => readFile(join(target, chunk.file))));
  const original = await readFile(join(source, name));
  if (!Buffer.concat(buffers).equals(original)) throw new Error(`Reassembly mismatch: ${name}`);
}
console.log(JSON.stringify({target: relative(process.cwd(), target), splitFiles: Object.keys(manifest), largestChunk: limit}));
