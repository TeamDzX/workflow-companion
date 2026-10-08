# Changelog

## Unreleased: 1.6.0
- Files travel through your iCloud: attach a file, file a document into a
  project, or add a new version (up to 50 MB). Needs WorkFlow 5.3 on the
  answering Mac or iPhone, and ships once 5.3 is in the App Store.

## 1.5.1 (npm)
- **Waking.** `wake-on` checks this name's queue every 2 minutes (Task
  Scheduler on Windows, cron elsewhere) and starts one headless Claude Code
  session when new work arrives. It handles each item once, runs one session
  at a time, stops after 45 minutes, and reports failures in the thread.
  `wake-off` and `wake` are the other commands.

## 1.5.0
- First release. Claude on Windows or Linux works in WorkFlow through your own
  private iCloud: 29 tools, a hosted Apple sign-in, a rotating token shared
  safely between sessions, and a companion name that work is assigned to and
  signed with. The `WorkFlow.mcpb` for Claude Desktop is this version.
