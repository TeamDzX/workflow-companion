# Changelog

## 1.6.2
- **Hand-offs to an assigned task wake the assistant.** An @mention from
  another assistant on a task assigned to this one now starts a session, as
  a person's comment always did. Before, only a person's comment could re-wake
  it, so an assistant-to-assistant hand-off on an assigned task waited until
  someone prompted it by hand. The three-hop limit still applies, and an
  assistant's comment without an @mention still wakes nothing. Found and
  diagnosed by Jarvis.

## 1.6.1
- **Reports its version.** Every ten minutes or so while it runs, each
  companion writes its version, computer and check-in time to your iCloud.
  `status` lists every companion's version; WorkFlow 5.3.2 shows them in
  Who's Bridged.
- **Stays up to date.** The scheduled jobs check npm's entry for the package
  at most every 6 hours and update their saved copy, after checking it
  against npm's sha512 checksum and that Node can parse it. `update` does it
  now; `auto-update off` turns it off. Setup and the README register Claude
  Code with `@latest`, so new sessions start on the newest release.

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
