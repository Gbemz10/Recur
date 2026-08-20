// Serves rendered email previews from /tmp/recur-emails during design work.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { join, normalize } from 'node:path';
const ROOT = '/tmp/recur-emails';
createServer(async (req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0]);
  const rel = normalize(url === '/' ? '/index.html' : url).replace(/^(\.\.[/\\])+/, '');
  try {
    const body = await readFile(join(ROOT, rel));
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(body);
  } catch { res.writeHead(404); res.end('not found'); }
}).listen(4174, () => console.log('emails on http://localhost:4174'));
