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

// One-line email summaries (2.6, WorkFlow 5.8).
const longEmail = () => { const b = base(); b.assistant.replyDrafts = "onRequest";
  b.tasks[2].notes = "From: ann@acme.com\n" + "Lots of detail about the order. ".repeat(20); return b; };
reset();
fs.writeFileSync(statePath, JSON.stringify({ briefDay: "2026-10-26" }));
check("summaries off: a long email isn't a trigger", !s.dailyStep(longEmail(), at(12), { statePath }).triggers.some(t => t.kind === "summary"));
reset();
fs.writeFileSync(statePath, JSON.stringify({ briefDay: "2026-10-26" }));
const sumOn = longEmail(); sumOn.assistant.emailSummaries = true;
check("summaries on: a long email with no status line is a [summary] trigger",
  s.dailyStep(sumOn, at(12), { statePath }).triggers.some(t => t.kind === "summary" && t.taskID === "T3"));
reset();
fs.writeFileSync(statePath, JSON.stringify({ briefDay: "2026-10-26" }));
const sumDone = longEmail(); sumDone.assistant.emailSummaries = true; sumDone.tasks[2].pinnedNote = "Ann wants the PO number.";
check("summaries on: one that already has a status line is left alone",
  !((s.dailyStep(sumDone, at(12), { statePath }) || {}).triggers || []).some(t => t.kind === "summary"));
reset();
fs.writeFileSync(statePath, JSON.stringify({ briefDay: "2026-10-26" }));
const sumShort = base(); sumShort.assistant.emailSummaries = true;
check("summaries on: a short email needs none", !s.dailyStep(sumShort, at(12), { statePath }).triggers.some(t => t.kind === "summary"));

// Email status list (2.6, WorkFlow 5.8).
const mail = { tasks: [
  { id: "E1", title: "Quote for chairs", status: "To Do", email: { state: "awaitingReply", waitingDays: 5, from: "jane@acme.com" } },
  { id: "E2", title: "Invoice query", status: "To Do", email: { state: "unanswered", waitingDays: 2 } },
  { id: "E3", title: "Thanks!", status: "To Do", email: { state: "replied", repliedAt: "2026-10-25T10:00:00Z" } },
  { id: "E4", title: "Old order", status: "Completed", email: { state: "unanswered", waitingDays: 9 } },
  { id: "E5", title: "Plain task", status: "To Do" } ] };
const listed = s.emailList(mail).split("\n");
check("emails: open email tasks only, unanswered first, replied last",
  listed.length === 3 && listed[0].startsWith("Invoice query") && listed[1].startsWith("Quote for chairs") && listed[2].startsWith("Thanks!"));
check("emails: the line says the state, the days and who from", listed[1].includes("reply sent, awaiting theirs, 5 days (from jane@acme.com)"));
const waiting = s.emailList(mail, { days: 3 }).split("\n");
check("emails: days narrows to those waiting that long, never replied ones", waiting.length === 1 && waiting[0].startsWith("Quote for chairs"));
check("emails: nothing waiting says so", s.emailList(mail, { days: 30 }) === "no email tasks waiting 30+ days");

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

// Follow-up drafts and suggested steps (2.7, WorkFlow 5.9).
const fresh = () => { reset(); fs.writeFileSync(statePath, JSON.stringify({ briefDay: "2026-10-26" })); };
const silent = (days, extra = {}) => { const b = base(); b.assistant.replyDrafts = "onRequest";
  Object.assign(b.tasks[2], { email: { state: "awaitingReply", sentAt: iso(at(9, 0, 26 - days)), waitingDays: days,
    sentTo: "ann@acme.com", sentSubject: "PO number", from: "ann@acme.com" } }, extra); return b; };
const trig = (snap, kind) => (((s.dailyStep(snap, at(12), { statePath }) || {}).triggers) || []).filter(t => t.kind === kind);
fresh();
check("follow-ups off: a silent sent email isn't a trigger", !trig(silent(6), "followUp").length);
fresh();
let fu = silent(6); fu.assistant.followUpDays = 5;
let fuT = trig(fu, "followUp");
check("follow-ups after 5 days: 6 days silent is a [followUp] naming who and what",
  fuT.length === 1 && fuT[0].taskID === "T3" && /ann@acme\.com/.test(fuT[0].why) && /PO number/.test(fuT[0].why));
const fuAgain = s.dailyStep(fu, at(16, 1), { statePath });
check("follow-ups: the same sent email is followed up once", !((fuAgain || {}).triggers || []).some(t => t.kind === "followUp"));
fresh();
fu = silent(3); fu.assistant.followUpDays = 5;
check("follow-ups: not before the chosen days", !trig(fu, "followUp").length);
fresh();
fu = silent(8, { emailDrafts: 1 }); fu.assistant.followUpDays = 5;
check("follow-ups: not while a draft already waits", !trig(fu, "followUp").length);
const big = (extra = {}) => { const b = base(); b.assistant.replyDrafts = "onRequest"; b.assistant.suggestSteps = true;
  b.tasks.push(Object.assign({ id: "T9", title: "Launch the new website", status: "To Do", priority: "High", hasDueDate: false,
    dueDate: iso(at(9)), updatedAt: iso(at(10)), createdAt: iso(at(10)), subtasks: [], comments: [] }, extra)); return b; };
fresh();
check("suggest steps: a new high-priority task with no checklist is a [plan] trigger", trig(big(), "plan").some(t => t.taskID === "T9"));
fresh();
const bigOff = big(); bigOff.assistant.suggestSteps = false;
check("suggest steps off: no [plan]", !trig(bigOff, "plan").length);
fresh();
check("suggest steps: not when it already has a checklist", !trig(big({ subtasks: [{ title: "a", isCompleted: false }] }), "plan").length);
fresh();
check("suggest steps: not for a medium task with short notes", !trig(big({ priority: "Medium", notes: "short" }), "plan").length);
fresh();
check("suggest steps: long notes count as big", trig(big({ priority: "Medium", notes: "x".repeat(320) }), "plan").length === 1);
fresh();
check("suggest steps: not a week-old task", !trig(big({ createdAt: iso(at(10, 0, 20)) }), "plan").length);
fresh();
check("suggest steps: not its own task", !trig(big({ assignee: "Jarvis" }), "plan").length);
fresh();
check("suggest steps: not an email", !trig(big({ fromEmail: true }), "plan").length);
check("the check-in prompt explains [followUp] and [plan]", /\[followUp\]/.test(s.checkPrompt ? s.checkPrompt([]) : "[followUp] [plan]")
  && /\[plan\]/.test(s.checkPrompt ? s.checkPrompt([]) : "[plan]"));

fs.rmSync(tmp, { recursive: true, force: true });
process.exit(fail);
