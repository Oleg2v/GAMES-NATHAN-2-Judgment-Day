/* Generated transport for static hosts with a per-file size limit. */
(() => {
  const manifest = {"index.pck":{"size":53120128,"type":"application/octet-stream","chunks":[{"file":"index.pck.00.f2f608b0d7d5.chunk","bytes":20000000,"sha256":"f2f608b0d7d5385c83bd4d6cf8aa149fc03ee66cf769d3ae87ed19094beb20a0"},{"file":"index.pck.01.045bf9759b1e.chunk","bytes":20000000,"sha256":"045bf9759b1eae98b0fdc3e602a8a5313590ab02493978728de31d7638b30499"},{"file":"index.pck.02.fd36fb9d83be.chunk","bytes":13120128,"sha256":"fd36fb9d83bee7d1b81157448a824924a2ff450841408925f57008e21ec8d71f"}]},"index.wasm":{"size":39514754,"type":"application/wasm","chunks":[{"file":"index.wasm.00.89cb9b28e041.chunk","bytes":20000000,"sha256":"89cb9b28e0411e0a1599f8cd7a92db55f37da8bb69bd204ab00ee54aa6a9ecbf"},{"file":"index.wasm.01.be330f6cbc38.chunk","bytes":19514754,"sha256":"be330f6cbc38c775e2a574752269fae53b6c5892f1900d6f899679e441782ff1"}]}};
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
