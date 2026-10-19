// The fake Mac: every 500 ms applies BridgeCommands (unless asleep).
const fs = require("fs"); const STATE = process.env.MOCK_STATE;
setInterval(() => {
  const s = JSON.parse(fs.readFileSync(STATE, "utf8"));
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
    s.records["receipt-" + name] = { recordName: "receipt-" + name, recordType: "BridgeReceipt", fields: { payload: { value: JSON.stringify({ id: cmd.id, op: cmd.op, status: "applied", message: "did " + cmd.op, taskID: cmd.taskID || (cmd.op === "create_task" ? "NEW-" + cmd.id.slice(-6) : undefined) }) } } };
    delete s.records[name];
  }
  fs.writeFileSync(STATE, JSON.stringify(s));
}, 500);
