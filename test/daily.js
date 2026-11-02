// The daily assistant's decisions (2.2, WorkFlow 5.6): when a brief or a
// check-in is due, what goes in them, and that each trigger is reported once.
// Loads the server as a module, as Jarvis in iCloud mode, with a throwaway
// HOME, so nothing real is read or written.
const fs = require("fs"), path = require("path"), os = require("os");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "daily-"));
process.env.HOME = tmp; process.env.USERPROFILE = tmp;
process.env.WF_MODE = "cloud"; process.env.WF_AGENT_NAME = "Jarvis";
const local = path.join(__dirname, "../../workflow-mcp/index.js");
const s = require(path.resolve(process.env.SERVER || (fs.existsSync(local) ? local : path.join(__dirname, "../src/index.js"))));
let fail = 0;
const check = (name, ok) => { console.log(`${ok ? "pass" : "FAIL"}  ${name}`); if (!ok) fail = 1; };
const at = (h, m = 0, d = 26) => new Date(2026, 9, d, h, m);
const iso = d => d.toISOString();
const statePath = path.join(tmp, "daily-state.json");
const reset = () => { try { fs.unlinkSync(statePath); } catch (_) {} };

const base = () => ({
  assistant: { dailyAssistant: "Jarvis", briefHour: 8, briefMinute: 0, checkEveryHours: 4, quietFrom: 21, quietUntil: 7, replyDrafts: "automatic" },
  brief: {},
  tasks: [
    { id: "T1", title: "Renew insurance", status: "To Do", hasDueDate: true, dueDate: iso(at(9, 0, 24)), updatedAt: iso(at(9, 0, 20)), createdAt: iso(at(9, 0, 20)), comments: [] },
    { id: "T2", title: "Call the bank", status: "To Do", hasDueDate: true, dueDate: iso(at(17)), updatedAt: iso(at(9, 0, 20)), createdAt: iso(at(9, 0, 20)), comments: [] },
    { id: "T3", title: "Invoice from Acme", status: "To Do", hasDueDate: false, dueDate: iso(at(9)), fromEmail: true, notes: "From: ann@acme.com\nCould you confirm the PO number?", updatedAt: iso(at(6)), createdAt: iso(at(6)), comments: [] },
    { id: "T4", title: "Tidy backlog", status: "To Do", hasDueDate: false, dueDate: iso(at(9)), updatedAt: iso(at(9, 0, 24)), createdAt: iso(at(9, 0, 20)),
      comments: [{ id: "c1", author: "Jarvis", authorID: "agent.jarvis", text: "📝 Proposal P7K2: Delete “old”\nwf-proposal: {}", timestamp: iso(at(9, 0, 24)) }] },
  ],
});

// Brief
reset();
check("no brief before 07:40 for an 08:00 brief", s.dailyStep(base(), at(7, 30), { statePath }) === null);
let step = s.dailyStep(base(), at(7, 45), { statePath });
check("the brief is due 20 minutes early, with its facts", step && step.kind === "brief" && step.facts && !step.facts.empty);
check("facts: overdue, due today, the waiting proposal", step.facts.overdue[0].id === "T1" && step.facts.dueToday[0].id === "T2"
  && step.facts.needsYou.some(n => n.kind === "proposal" && n.code === "P7K2"));
const again = s.dailyStep(base(), at(7, 50), { statePath });
check("once a day: the next tick doesn't brief again", !again || again.kind !== "brief");
reset();
const done = base(); done.brief = { writtenAt: iso(at(7, 41)), by: "Jarvis" };
check("a brief already written today isn't repeated", (s.dailyStep(done, at(7, 45), { statePath }) || {}).kind !== "brief");
reset();
check("a brief more than three hours late is skipped", (s.dailyStep(base(), at(11, 0), { statePath }) || {}).kind !== "brief");
reset();
const quiet = base(); quiet.tasks = [];
const q = s.dailyStep(quiet, at(7, 45), { statePath });
check("nothing to say: no brief session", q && q.kind === "brief" && q.skipped);
reset();
const other = base(); other.assistant.dailyAssistant = "Claude";
check("only the daily assistant briefs", s.dailyStep(other, at(7, 45), { statePath }) === null);

// Check-ins
reset();
fs.writeFileSync(statePath, JSON.stringify({ briefDay: "2026-10-26" }));
step = s.dailyStep(base(), at(12), { statePath });
const kinds = step && step.triggers ? step.triggers.map(t => `${t.kind}:${t.taskID}`) : [];
check("a check-in finds overdue, due soon, the email asking something, and the day-old proposal",
  step.kind === "check" && kinds.includes("overdue:T1") && kinds.includes("dueSoon:T2") && kinds.includes("reply:T3") && kinds.includes("waiting:T4"));
check("not again within the interval", s.dailyStep(base(), at(13), { statePath }) === null);
const later = s.dailyStep(base(), at(16, 1), { statePath });
check("after the interval, nothing already reported counts again", later && later.kind === "check" && later.skipped);
reset();
fs.writeFileSync(statePath, JSON.stringify({ briefDay: "2026-10-26" }));
check("no check-ins in quiet hours", s.dailyStep(base(), at(22), { statePath }) === null);
check("quiet hours wrap past midnight", s.inQuietHours({ quietFrom: 21, quietUntil: 7 }, at(3)) && !s.inQuietHours({ quietFrom: 21, quietUntil: 7 }, at(12)));
reset();
fs.writeFileSync(statePath, JSON.stringify({ briefDay: "2026-10-26" }));
const onReq = base(); onReq.assistant.replyDrafts = "onRequest";
const r2 = s.dailyStep(onReq, at(12), { statePath });
check("reply drafts on request: emails aren't check-in triggers", !r2.triggers.some(t => t.kind === "reply"));
const answered = base();
answered.tasks[3].comments.push({ id: "c2", author: "Alex", authorID: "_alex", text: "✓ Applied P7K2", timestamp: iso(at(10, 0, 24)) });
check("an applied proposal no longer waits", !s.pendingForPerson(answered, at(12)).some(p => p.code === "P7K2"));

// Weekly review (2.3, WorkFlow 5.7). 26 Oct 2026 is a Monday, 30 Oct a Friday.
const weekly = when => { const b = base(); b.assistant.weeklyReview = when; b.assistant.checkEveryHours = 0;
  b.tasks.push({ id: "T5", title: "Ship 5.6.2", status: "Completed", completedDate: iso(at(15, 0, 28)), hasDueDate: false, dueDate: iso(at(9)), updatedAt: iso(at(15, 0, 28)), createdAt: iso(at(9, 0, 20)), comments: [] });
  return b; };
reset();
check("review off: nothing on a Friday afternoon", s.dailyStep(weekly("off"), at(16, 30, 30), { statePath }) === null);
reset();
check("Friday review: not before 16:00", s.dailyStep(weekly("friday"), at(15, 30, 30), { statePath }) === null);
let rv = s.dailyStep(weekly("friday"), at(16, 30, 30), { statePath });
check("Friday review is due from 16:00, with the week's facts", rv && rv.kind === "review" && rv.facts
  && rv.facts.done.some(t => t.id === "T5") && rv.facts.nextWeek.length >= 0);
check("once a week: the next tick doesn't review again", (s.dailyStep(weekly("friday"), at(17, 0, 30), { statePath }) || {}).kind !== "review");
reset();
fs.writeFileSync(statePath, JSON.stringify({ briefDay: "2026-10-26" }));
rv = s.dailyStep(weekly("monday"), at(8, 10, 26), { statePath });
check("Monday review comes after the brief is handled", rv && rv.kind === "review");
reset();
rv = s.dailyStep(weekly("monday"), at(7, 45, 26), { statePath });
check("on Monday the brief goes first", rv && rv.kind === "brief");
reset();
const empty = weekly("friday"); empty.tasks = [];
rv = s.dailyStep(empty, at(16, 30, 30), { statePath });
check("nothing to review: no session", rv && rv.kind === "review" && rv.skipped);
check("the review prompt names the week's note", /Week of 26 Oct/.test(s.reviewPrompt(s.reviewFacts(weekly("friday"), at(16, 30, 30)))));

fs.rmSync(tmp, { recursive: true, force: true });
process.exit(fail);
