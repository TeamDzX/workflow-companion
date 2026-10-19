// Adds a comment to task T3 in the served snapshot and changes its sha, as
// the Mac does when a task changes.
//   node bump.js <sha> <authorID> <author> <text> [taskID, default T3]
const fs = require("fs");
const f = process.env.MOCK_STATE;
const [sha, authorID, author, text, taskID = "T3"] = process.argv.slice(2);
let snap;
try { snap = JSON.parse(fs.readFileSync(f + ".snap", "utf8")); } catch (_) { snap = JSON.parse(JSON.stringify(require("./mock.js").snap)); }
snap.tasks.find(t => t.id === taskID).comments.push({ author, authorID, text, timestamp: new Date().toISOString() });
fs.writeFileSync(f + ".snap", JSON.stringify(snap));
const s = JSON.parse(fs.readFileSync(f, "utf8"));
s.records.snapshot.fields.sha.value = sha;
fs.writeFileSync(f, JSON.stringify(s));
