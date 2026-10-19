// Spawns the server, sends requests, prints responses.
const { spawn } = require("child_process");
const calls = JSON.parse(process.argv[2]);
const p = spawn("node", ["-r", __dirname + "/mock.js", process.env.SERVER, "--cloud"], { env: process.env });
let out = ""; p.stdout.on("data", d => out += d); p.stderr.on("data", d => process.stderr.write(d));
const reqs = [{ jsonrpc: "2.0", id: 0, method: "initialize", params: {} }].concat(calls.map((c, i) => ({ jsonrpc: "2.0", id: i + 1, method: "tools/call", params: { name: c[0], arguments: c[1] || {} } })));
for (const r of reqs) p.stdin.write(JSON.stringify(r) + "\n");
p.stdin.end();
p.on("exit", code => { for (const l of out.trim().split("\n")) { const j = JSON.parse(l); if (j.id) console.log(`#${j.id} ${j.result.isError ? "ERR" : "ok "} ${j.result.content[0].text.replace(/\n/g, "\n    ")}`); } console.log("exit", code); });
