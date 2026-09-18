import { createServer } from 'node:http';
import worker from '../dist/server/index.js';

const port = Number(process.env.DUO_PORT || 4173);

const server = createServer(async (request, response) => {
  const protocol = 'http';
  const host = request.headers.host || `127.0.0.1:${port}`;
  const url = `${protocol}://${host}${request.url || '/'}`;
  const chunks = [];
  for await (const chunk of request) chunks.push(chunk);
  const body = Buffer.concat(chunks);
  const webRequest = new Request(url, {
    method: request.method,
    headers: request.headers,
    body: ['GET', 'HEAD'].includes(request.method || 'GET') ? undefined : body
  });
  const webResponse = await worker.fetch(webRequest, { OPENAI_API_KEY: process.env.OPENAI_API_KEY });
  response.statusCode = webResponse.status;
  webResponse.headers.forEach((value, key) => response.setHeader(key, value));
  response.end(Buffer.from(await webResponse.arrayBuffer()));
});

server.listen(port, '127.0.0.1', () => {
  console.log(`Duo Translate local server: http://127.0.0.1:${port}`);
});
