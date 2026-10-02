'use strict';
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { handler } = require('./core.cjs');
const root = path.resolve(__dirname, '../build/web');
const port = Number(process.env.PORT || 5050);
const host = process.env.HOST || '127.0.0.1';
const types = { '.html':'text/html; charset=utf-8', '.js':'application/javascript', '.css':'text/css', '.json':'application/json', '.wasm':'application/wasm', '.png':'image/png', '.svg':'image/svg+xml', '.woff2':'font/woff2', '.ttf':'font/ttf', '.ico':'image/x-icon' };
if (!fs.existsSync(path.join(root, 'index.html'))) { console.error('Önce flutter build web --release komutunu çalıştırın.'); process.exit(1); }
const server = http.createServer((req, res) => {
  let url;
  try { url = new URL(req.url, 'http://localhost'); } catch { res.writeHead(400); res.end(); return; }
  if (['/api/score','/api/dataset'].includes(url.pathname)) { require('./analysis-handler.cjs').handler(url.pathname)(req,res); return; }
  if (url.pathname.startsWith('/api/')) { handler(url.pathname)(req, res); return; }
  if (!['GET','HEAD'].includes(req.method)) { res.writeHead(405); res.end(); return; }
  let name;
  try { name = decodeURIComponent(url.pathname); } catch { res.writeHead(400); res.end(); return; }
  const file = path.resolve(root, '.' + (name === '/' ? '/index.html' : name));
  if (!file.startsWith(root + path.sep)) { res.writeHead(403); res.end(); return; }
  fs.stat(file, (err, stat) => {
    if (err || !stat.isFile()) { res.writeHead(404); res.end('404'); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Content-Length': stat.size, 'Cache-Control':'no-cache', 'X-Content-Type-Options':'nosniff' });
    if (req.method === 'HEAD') { res.end(); return; }
    const stream = fs.createReadStream(file); stream.on('error', () => res.destroy()); stream.pipe(res);
  });
});
server.on('error', error => { console.error(error.code === 'EADDRINUSE' ? `${port} portu kullanımda. Eski server.ps1 penceresinde Ctrl+C yapın.` : error.message); process.exitCode = 1; });
server.listen(port, host, () => console.log(`TradeMind Flutter: http://localhost:${port} | API aynı adreste`));
