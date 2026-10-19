const fs = require("fs");
fs.writeFileSync(process.env.MOCK_STATE, JSON.stringify({ token: "tok0", n: 0, calls: [], rejected: 0, downloads: 0, applied: [], asleep: false, noZone: false, expired: false,
  records: {
    snapshot: { recordName: "snapshot", recordType: "BridgeSnapshot", fields: { sha: { value: "abc" }, snapshot: { value: { downloadURL: "https://assets.mock/${f}" } } } },
    status: { recordName: "status", recordType: "BridgeStatus", fields: { aliveAt: { value: Date.now() - 60000 }, appVersion: { value: "5.2" }, device: { value: "Alex's MacBook" }, pollSeconds: { value: 15 } } },
  } }));
