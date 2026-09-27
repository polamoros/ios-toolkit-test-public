// The UI tests' server: invented data only, and a request counter the tests
// read at /__requests. Add a route per API call the app makes; an unknown
// path answers 404 and is logged, so a missing fixture is named, not guessed.
import { createServer } from "node:http";

const PORT = Number(process.env.PORT ?? 8787);
let requests = 0;

const routes = {
  "/items": () => ["First item", "Second item", "Third item"],
};

createServer((req, res) => {
  const path = new URL(req.url, "http://x").pathname;
  if (path === "/__requests") { res.end(String(requests)); return; }
  if (path === "/health") { res.end("ok"); return; }
  requests++;
  console.log(new Date().toISOString(), req.method, path);
  const route = routes[path];
  if (!route) { console.log("  no fixture for", path); res.writeHead(404).end(); return; }
  res.writeHead(200, { "content-type": "application/json" }).end(JSON.stringify(route(req)));
}).listen(PORT, "127.0.0.1", () => console.log(`[mock-server] http://127.0.0.1:${PORT}`));
