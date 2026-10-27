// The fake Mac: every 500 ms applies BridgeCommands (unless asleep).
const fs = require("fs"); const STATE = process.env.MOCK_STATE;
const { locked } = require("./mock.js");
setInterval(() => locked(() => {
  let s;
  try { s = JSON.parse(fs.readFileSync(STATE, "utf8")); } catch (_) { return; }   // mid-write: next tick
  if (s.asleep) return;
  for (const [name, r] of Object.entries(s.records)) if (r.recordType === "BridgeCommand") {
    const cmd = JSON.parse(r.fields.payload.value);
    // A file command names an upload: it must be there, with its asset,
    // and it is consumed with the command (as CloudBridge does).
    if (cmd.upload) {
      const up = s.records[cmd.upload];
      cmd.uploadFound = !!(up && up.recordType === "BridgeSnapshot" && up.fields.snapshot && up.fields.snapshot.value.receipt);
      cmd.uploadBytes = up ? up.fields.snapshot.value.size : 0;
      delete s.records[cmd.upload];
    }
    s.applied.push(cmd);
    // As WorkFlow does: a change shows in the next published snapshot (1.9's
    // self-test reads it back). Only the two the self-test needs.
    if (cmd.op === "create_task" || (cmd.op === "update_task" && cmd.pinnedNote !== undefined)) {
      let snap; try { snap = JSON.parse(fs.readFileSync(STATE + ".snap", "utf8")); } catch (_) { snap = JSON.parse(JSON.stringify(require("./mock.js").snap)); }
      if (cmd.op === "create_task") snap.tasks.push({ id: "NEW-" + cmd.id.slice(-6), title: cmd.title, status: "To Do", priority: cmd.priority || "Medium", assignee: cmd.assignee || "", pinnedNote: "", comments: [] });
      else { const t = snap.tasks.find(x => x.id === cmd.taskID); if (t) t.pinnedNote = cmd.pinnedNote; }
      fs.writeFileSync(STATE + ".snap", JSON.stringify(snap));
      if (s.records.snapshot) s.records.snapshot.fields.sha.value = "mac-" + cmd.id;
    }
    // get_attachment (WorkFlow 5.6.1): the file goes back as a "download-…"
    // record the receipt names, as CloudBridge.publishDownload does.
    if (cmd.op === "get_attachment") {
      const bytes = Buffer.from(cmd.documentID === "D1" ? "date,temp\n2026-10-27,14.5\n" : "some bytes");
      const rec = "download-" + name;
      s.files = s.files || {}; s.files[rec] = bytes.toString("base64");
      s.records[rec] = { recordName: rec, recordType: "BridgeSnapshot", fields: { snapshot: { value: { downloadURL: `https://files.mock/${rec}/\${f}` } } } };
      const sha = require("crypto").createHash("sha256").update(cmd.documentID === "D1" ? bytes : Buffer.from("other")).digest("hex");
      s.records["receipt-" + name] = { recordName: "receipt-" + name, recordType: "BridgeReceipt", fields: { payload: { value: JSON.stringify({ id: cmd.id, op: cmd.op, status: "applied", message: "WF-x v1", download: rec, fileName: cmd.documentID === "D1" ? "readings.csv" : "broken.bin", bytes: bytes.length, sha256: sha }) } } };
      delete s.records[name];
      continue;
    }
    s.records["receipt-" + name] = { recordName: "receipt-" + name, recordType: "BridgeReceipt", fields: { payload: { value: JSON.stringify({ id: cmd.id, op: cmd.op, status: "applied", message: "did " + cmd.op, taskID: cmd.taskID || (cmd.op === "create_task" ? "NEW-" + cmd.id.slice(-6) : undefined) }) } } };
    delete s.records[name];
  }
  const t = `${STATE}.${process.pid}.tmp`; fs.writeFileSync(t, JSON.stringify(s)); fs.renameSync(t, STATE);
}), 500);
