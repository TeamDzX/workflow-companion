# Changelog

## 2.0.0
- **15 tools instead of 37.** Related tools are merged, so every session
  starts with a shorter, clearer list (about a fifth fewer tokens up front)
  and Claude has fewer near-duplicates to choose between:
  - `workflow_list` (kind: tasks, notes, projects, documents, comments), now
    with `query`, `project`, `status` and `limit` for tasks and notes too;
  - `workflow_get` finds a task, note or document by id, WF-number or title;
  - `workflow_update_task` takes `status_line` and the whole checklist
    (`check_subtasks`, `uncheck_subtasks`, `add_subtasks`, `remove_subtasks`,
    `rename_subtasks`) in one call, so one WorkFlow command instead of several;
  - `workflow_comment` takes `hand_to` (was `workflow_hand_off`);
  - `workflow_note` (create / reply / convert), `workflow_attach` (task,
    project or new document version), `workflow_approval` (request / check /
    run), and `workflow_state` with `check: ping` or `doctor`;
  - house rules lead `workflow_queue`.
- **The old names still work.** They are no longer listed, but a prompt, a
  saved permission or an older WorkFlow app that calls one gets the same
  result as before.
- Read-only tools say so (MCP `readOnlyHint`), so clients that honour it can
  run them without asking.

## 1.9.0
- **A daily self-test.** Once a day (07:30 unless you change it with
  `canary at HH:MM`), with waking on, the companion checks itself end to
  end: doctor's checks, a command WorkFlow must apply, and a tiny real
  Claude session whose change has to come back through WorkFlow. A pass
  only updates the status line of its own "⚙︎ <name> daily self-test"
  task, so nothing pings you. A failure comments there (reaching your phone)
  with the step that failed and the fix, shows "needs attention" in Who's
  Bridged, and a notice on the computer; a recovery says so. Run it now with
  `workflow-companion canary`; `canary off` stops it. Costs one very short
  Claude session a day.
- `doctor` shows the last self-test.

## 1.8.2
- **Shared projects never start a session.** A task assigned to the
  companion in a shared project no longer wakes it, or appears in its queue:
  a collaborator can assign tasks and comment there, so it isn't only you
  asking. (WorkFlow on the Mac has always refused these; @mentions in shared
  projects were already ignored.)
- **Shared rule tests.** The rules for which comment asks an assistant for
  something are checked against the same cases as WorkFlow's own, on every
  change, so the two can't drift apart again.

## 1.8.1
- **`workflow-companion doctor`** checks everything on this computer in one
  go: Node.js, the iCloud sign-in, whether WorkFlow is publishing and
  answering (with a test command), the name, the version, the scheduled
  jobs, Claude Code, the last session, monitors and approvals. It says how
  to fix whatever is wrong. Claude can run it too (`workflow_doctor`).
- **Released by GitHub.** Each release is tested, published to npm with
  provenance, attached to a GitHub Release and sent to the MCP Registry by
  GitHub Actions.

## 1.8.0
The companion now does useful work on its computer by itself.
- **Monitors.** Website, port, disk, process, file and (yours only) command
  checks every few minutes, without using Claude. A change is posted on a
  task and can wake a session.
- **Approvals.** An assistant asks to run one exact command; you reply
  "approve CODE" from your phone, and it runs once. Off until you switch it
  on with `workflow-companion approvals on`.
- **Session reports.** A short report attached to the task after each
  session.
- **Sign-in ended.** Said on the computer itself, once, with the fix.
- **Inbox folder.** Files dropped in become tasks.
- **Notifications** on the computer.
- **One-line install** for Windows, Mac and Linux.

## 1.7.0
Ideas from OpenRig, adapted for WorkFlow 5.4.
- **Hand-offs.** `workflow_hand_off` gives a task to another assistant or a
  person: it becomes the assignee, and a comment says so. Handing to an
  assistant @mentions it, which starts its session.
- **Watches.** `workflow_watch` sets a task aside and wakes this assistant
  at a set time to look again ("tell me when the server's back up"). Give
  minutes, or a time as ISO-8601 or HH:MM. A watch fires once; set it again
  to keep watching. Needs WorkFlow 5.4.
- **House rules.** The user's standing instructions for every assistant,
  set in WorkFlow (Settings → Agent Bridge → House Rules). They head
  `workflow_queue`, are in every wake prompt, and `workflow_house_rules`
  returns them.
- **What it's doing.** The companion reports whether it's working on a
  task, idle, or needs attention (a usage limit, a sign-in, Claude Code
  missing, a session stopped at the time limit). WorkFlow 5.4 shows this in
  Who's Bridged, and `status` lists it. Until the WorkFlow 5.4 schema is
  live in iCloud, the presence record goes without it.

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
