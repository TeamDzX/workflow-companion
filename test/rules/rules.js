// The companion's side of the shared rule cases. Loads the companion as a
// module, as the assistant named in WF_AGENT_NAME (or Claude, in the Mac's
// folder mode), and prints, for each case for that assistant, which comment
// it treats as the current request: {"name": ..., "trigger": index|null}.
//   SERVER=path/to/index.js node rules.js Jarvis|Claude
const fs = require("fs"), path = require("path"), os = require("os");
const who = process.argv[2];
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "agent-rules-"));
process.env.HOME = tmp;
if (who === "Claude") { process.env.WF_MODE = "folder"; process.env.WF_BRIDGE = tmp; }
else { process.env.WF_MODE = "cloud"; process.env.WF_AGENT_NAME = who; }
// WorkFlow's copy (Tools/workflow-mcp), or src/ in the public repo.
const local = path.join(__dirname, "../workflow-mcp/index.js");
const server = require(path.resolve(process.env.SERVER || (fs.existsSync(local) ? local : path.join(__dirname, "../src/index.js"))));
const idOf = name => "agent." + name.toLowerCase();
const { cases } = JSON.parse(fs.readFileSync(path.join(__dirname, "cases.json"), "utf8"));
const base = Date.parse("2026-10-01T09:00:00Z");
const out = [];
for (const c of cases.filter(c => c.agent === who)) {
  const comments = c.comments.map(([by, text], i) => ({
    id: `c${i}`, text, timestamp: new Date(base + i * 60000).toISOString(),
    author: by === "person" ? "Alex" : by === "self" ? who : by,
    authorID: by === "person" ? "_alex" : idOf(by === "self" ? who : by),
  }));
  const project = c.shared ? "Client" : who === "Claude" && c.assigned ? "Claude" : "Ops";
  const snap = { tasks: [{ id: "T", title: c.name, status: "To Do", project, assignee: c.assigned ? who : "", comments }],
    projects: [{ name: "Client", isShared: true }, { name: "Ops", isShared: false }, { name: "Claude", isShared: false }], notes: [] };
  const item = server.wakeItems(snap).find(i => i.id === "T");
  const m = item && /^c(\d+)@/.exec(item.sig);
  out.push({ name: c.name, trigger: m ? Number(m[1]) : null });
}
console.log(JSON.stringify(out));
fs.rmSync(tmp, { recursive: true, force: true });
