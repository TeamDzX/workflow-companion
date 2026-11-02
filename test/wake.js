// Who wakes, and who doesn't (2.3, WorkFlow 5.7): the hop limit holds for
// hand_to reassignments too, and the agent id follows WorkFlow's rule.
// Loads the server as a module, as Jarvis in iCloud mode, with a throwaway HOME.
const fs = require("fs"), path = require("path"), os = require("os");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "wake-"));
process.env.HOME = tmp; process.env.USERPROFILE = tmp;
process.env.WF_MODE = "cloud"; process.env.WF_AGENT_NAME = "Jarvis";
const local = path.join(__dirname, "../../workflow-mcp/index.js");
const s = require(path.resolve(process.env.SERVER || (fs.existsSync(local) ? local : path.join(__dirname, "../src/index.js"))));
let fail = 0;
const check = (name, ok) => { console.log(`${ok ? "pass" : "FAIL"}  ${name}`); if (!ok) fail = 1; };
const c = (by, text, i) => ({ id: `c${i}`, author: by, authorID: by === "Me" ? "user.me" : `agent.${by.toLowerCase()}`, text, timestamp: new Date(2026, 9, 30, 9, i).toISOString() });
const task = comments => ({ snap: { tasks: [{ id: "T1", title: "Pass it on", status: "To Do", assignee: "Jarvis", comments }] } });
const woken = comments => s.wakeItems(task(comments).snap).length > 0;

check("a task assigned by a person wakes", woken([]));
check("assigned with the person's comment last wakes", woken([c("Me", "please do this", 1)]));
check("three hand-offs in a row still wake", woken([c("Me", "hi", 1), c("Claude", "@Jarvis yours", 2), c("Jarvis", "@Claude no", 3), c("Claude", "@Jarvis yours", 4)]));
check("one hand_to from Claude wakes", woken([c("Me", "hi", 1), c("Claude", "@Jarvis over to you", 2)]));
const pingPong = [c("Me", "hi", 1), c("Claude", "@Jarvis yours", 2), c("Jarvis", "@Claude no, yours", 3),
  c("Claude", "@Jarvis really yours", 4), c("Jarvis", "@Claude back to you", 5), c("Claude", "@Jarvis no, you", 6)];
check("a hand_to past the hop limit doesn't wake", !woken(pingPong));
check("past the limit without a mention of Jarvis doesn't wake either",
  !woken(pingPong.concat([c("Claude", "@Opticell can you look", 7)])));
check("a person writing again resets it", woken(pingPong.concat([c("Me", "Jarvis, take it", 7)])));

check("agent id keeps the underscore, as WorkFlow does", s.agentFor("My_Bot").authorID === "agent.my_bot");
check("agent id is the lower-cased name", s.agentFor("Jarvis").authorID === "agent.jarvis");
process.exit(fail);
