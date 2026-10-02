const http = require('http');
const fs = require('fs');
const path = require('path');

// API routes
const health = require('./api/health');
const scan = require('./api/scan');
const detail = require('./api/detail');
const score = require('./api/score');
const dataset = require('./api/dataset');
const kap = require('./api/kap');

const PORT = process.env.PORT || 3000;

const mimeTypes = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

const server = http.createServer((req, res) => {
  console.log(`${req.method} ${req.url}`);

  // API routes
  if (req.url.startsWith('/api/')) {
    if (req.url === '/api/health') {
      health(req, res);
    } else if (req.url.startsWith('/api/scan')) {
      scan(req, res);
    } else if (req.url.startsWith('/api/detail')) {
      detail(req, res);
    } else if (req.url.startsWith('/api/score')) {
      score(req, res);
    } else if (req.url.startsWith('/api/dataset')) {
      dataset(req, res);
    } else if (req.url.startsWith('/api/kap')) {
      kap(req, res);
    } else {
      res.statusCode = 404;
      res.end(JSON.stringify({ error: 'API endpoint not found' }));
    }
    return;
  }

  // Serve static files
  let filePath = '.' + req.url;
  if (filePath === './') {
    filePath = './index.html';
  }

  const extname = String(path.extname(filePath)).toLowerCase();
  const contentType = mimeTypes[extname] || 'application/octet-stream';

  fs.readFile(filePath, (error, content) => {
    if (error) {
      if (error.code === 'ENOENT') {
        res.writeHead(404, { 'Content-Type': 'text/html' });
        res.end('<h1>404 Not Found</h1>', 'utf-8');
      } else {
        res.writeHead(500);
        res.end(`Server Error: ${error.code}`, 'utf-8');
      }
    } else {
      res.writeHead(200, { 'Content-Type': contentType });
      res.end(content, 'utf-8');
    }
  });
});

server.listen(PORT, () => {
  console.log(`TradeMind API server running on port ${PORT}`);
  console.log(`API endpoints:`);
  console.log(`  - http://localhost:${PORT}/api/health`);
  console.log(`  - http://localhost:${PORT}/api/scan`);
  console.log(`  - http://localhost:${PORT}/api/detail`);
  console.log(`  - http://localhost:${PORT}/api/score`);
  console.log(`  - http://localhost:${PORT}/api/dataset`);
  console.log(`  - http://localhost:${PORT}/api/kap`);
});