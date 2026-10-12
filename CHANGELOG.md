# Changelog

## 1.6.0
- **Files travel through your iCloud.** Attach a file, file a document into a
  project, or add a new version, up to 50 MB a file. Needs WorkFlow 5.3 on the
  answering device. WorkFlow 5.3 is out on iPhone and iPad; the Mac update
  (5.3.1) is in App Review. Until it lands, a Mac on 5.2.3 that answers
  ignores the upload and reports the file as missing.
- **Hand-offs between assistants.** An @mention from another assistant now
  counts as a request, with the newest request winning, and at most three
  assistant hops since a person last spoke.

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
