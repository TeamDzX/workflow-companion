# WorkFlow Companion

[![npm](https://img.shields.io/npm/v/@opticell/workflow-companion?label=npm)](https://www.npmjs.com/package/@opticell/workflow-companion)
[![MCP Registry](https://img.shields.io/badge/MCP_Registry-io.github.TeamDzX%2Fworkflow--companion-4F46E5)](https://registry.modelcontextprotocol.io/v0/servers?search=io.github.TeamDzX/workflow-companion)

> **This repository** is WorkFlow Companion's home: the source (`src/index.js`,
> MIT licensed), downloads (`WorkFlow.mcpb` for Claude Desktop) on the
> [Releases](https://github.com/TeamDzX/workflow-companion/releases) page,
> and bugs and requests in [Issues](https://github.com/TeamDzX/workflow-companion/issues).
> The package itself installs from npm. On a Mac, use the open-source
> [workflow-agent-bridge](https://github.com/TeamDzX/workflow-agent-bridge) instead.
> All of Opticell's free tools for Claude: [opticell-mcp](https://github.com/TeamDzX/opticell-mcp).

Lets **Claude on Windows or Linux** work in your WorkFlow tasks, notes and
projects: reading the queue, replying in threads, ticking checklists, filing
notes, updating documents. It works in Claude Code, Claude Desktop, or any MCP
client.

Free. It needs **WorkFlow 5.2 or later on an iPhone, iPad or Mac**, which does
the actual work. No Mac needed:

```
Claude ──MCP──▶ companion ──▶ your private iCloud ──▶ WorkFlow on your iPhone, iPad or Mac
                                                  ◀── receipt + fresh snapshot
```

The companion never edits your WorkFlow data itself. It leaves commands in a
zone of your own private iCloud database. WorkFlow applies them with the same
checks as the app (read-only trial gate, email permission, the agent's
signature) and lists every one in **Command History**. Nothing passes through
Opticell's servers.

**Which device answers.** A Mac with WorkFlow open answers within seconds. An
iPhone or iPad answers when iOS lets WorkFlow run: usually within minutes,
sometimes only when you next open it, and not while WorkFlow has been swiped
away in the app switcher. With both switched on, the Mac answers while it's
awake and the iPhone stands by. Every command is applied exactly once, however
many devices are on.

## Set up

1. In WorkFlow on an iPhone or iPad: **Settings → Windows Companion → Answer
   the Companion**. On a Mac: **Settings → Agent Bridge**, then the Agent
   Bridge and **Cloud Bridge** switches.
2. Install **Node.js 18 or later** (LTS) if `node -v` doesn't show it:
   Windows `winget install OpenJS.NodeJS.LTS -e`, Mac `brew install node`,
   Linux your package manager, or the installer from <https://nodejs.org>.
   Then close and reopen the terminal (and restart Claude Code) so `node` and
   `npx` are found; otherwise you'll see "node is not recognized".
3. In a normal terminal window:

   ```sh
   npx -y @opticell/workflow-companion@latest setup
   ```

   It opens <https://companion.opticell-limited.com> to sign in with the
   Apple Account WorkFlow uses on your iPhone or Mac, then asks you to paste the token that
   page shows. It asks questions, so it can't run from Claude Code's `!`
   prompt or another non-interactive shell; there, pass `--web-token <token>`
   and `--name <name>`.
4. Add it to Claude:

   ```sh
   claude mcp add --scope user workflow -- npx -y @opticell/workflow-companion@latest
   ```

   On **Windows**, `npx` is a script, so Claude Code needs `cmd /c` in front:

   ```sh
   claude mcp add --scope user workflow -- cmd /c npx -y @opticell/workflow-companion@latest
   ```

   `--scope user` makes it available in every project on this computer.

   **Claude Desktop** needs no terminal. Download `WorkFlow.mcpb` from the
   product page and double-click it. Then sign in at
   <https://companion.opticell-limited.com> and paste the token into
   **Settings → Extensions → WorkFlow Companion → Sign-in token**.

Check it any time with `npx -y @opticell/workflow-companion status`.

## Its name

Setup asks what Claude on this computer should be called in WorkFlow
("Companion" unless you choose, e.g. `--name Server`). That name is how work
reaches it rather than the Mac's own Claude:

- **Assign a task** to it. WorkFlow offers the name once it has heard from
  the companion, and the Ask sheet lets you pick it.
- **Write `@Server`** in a comment or a note. A mention in a *shared*
  project's thread doesn't count, because other people can write there.
- What it writes is **signed with its name**, so a thread shows which Claude
  did what.
- **One name, one computer.** Setup refuses a name another computer already
  answers to, and asks for another. Every command is checked the same way,
  which covers Claude Desktop, where the name is a setting. Use
  `setup --takeover` when this computer replaces the other one. A name frees
  up by itself once its computer has been silent for two weeks.
- `@Claude` always means Claude on the Mac. A companion can't take that name,
  and mentions match whole words only, so `@Claude2` never wakes the Mac.

Claude Desktop users set the name in the extension's settings.

## Working on its own

With waking on, `@Server` from the app is enough: nobody has to be at this
computer. Turn it on once Claude Code is installed and signed in here:

```sh
npx -y @opticell/workflow-companion wake-on
```

- **Every 2 minutes** a hidden scheduled job (Task Scheduler on Windows, cron
  elsewhere) checks this name's queue in iCloud. That's one small call; the
  task list is downloaded only when it changed.
- **New work starts one Claude Code session** (`claude -p`, no window). It
  reads the task, comments that it's picked it up (your phone shows
  "Server is on it"), does the work and replies in the thread.
- **What counts as new:** a task newly assigned to the name, a new `@Server`
  comment from a person, a person's follow-up on an assigned task, or an
  edited note that mentions it. Its own replies never wake it.
- **Handled once.** One session at a time; work already handled never starts
  another. A session that couldn't start at all (not signed in to Claude, a
  usage limit) is retried twice more, then says so in the thread.
- **A time limit**, 45 minutes by default (`--max-minutes`). A session stopped
  by it says so in the thread.
- **What it may do.** By default only the WorkFlow tools (`mcp__workflow`):
  reading tasks and replying. To let it run commands on this computer, pass
  `--allow-tools "mcp__workflow Bash Read"` (any Claude Code permission rules).
  Anyone who can write `@Server` in your WorkFlow could then run commands
  here, so decide that deliberately. Shared projects never reach it.
- **Windows:** a scheduled task normally runs only while the user is logged
  in. To run while logged off, change the task "WorkFlow Companion wake" to
  "Run whether user is logged on or not" in Task Scheduler.
- `--workdir` sets the folder sessions start in (your home folder otherwise),
  `--model` the Claude model, `--claude` the path to Claude Code if it isn't
  found. `--skip-existing` treats what's already queued as handled.
- The log is `~/.workflow-companion/wake.log`. `wake-off` stops it all.

## Staying up to date

- **Claude Code** runs whatever its registration names. Register it with
  `@latest` (setup prints the exact line) and every new session uses the
  newest release.
- **The scheduled jobs** (keep-alive, waking) run a saved copy that npm never
  touches, so they update themselves. At most every 6 hours they read npm's
  entry for the package (`registry.npmjs.org/@opticell/workflow-companion/latest`).
  When it's newer, they download the release, check it against npm's sha512
  checksum and that Node can parse it, then swap it in. Turn this off with
  `auto-update off`, and update by hand with `update`.
- **Its version is reported.** Every ten minutes or so while it runs, each
  companion writes its version, computer and check-in time to your iCloud.
  WorkFlow 5.3.2 shows them in Settings → Agent Bridge → Who's Bridged, and
  `status` lists every companion's version.

## Commands

| | |
|---|---|
| `workflow-companion` | Runs the MCP server. This is what Claude starts. |
| `workflow-companion setup` | Signs this computer in. Takes `--web-token` to skip the prompt. |
| `workflow-companion status` | Which device answers, how fresh the snapshot is, any receipts that arrived late. |
| `workflow-companion keepalive` | Renews the sign-in. The scheduled job runs this. |
| `workflow-companion update` | Updates the scheduled jobs' copy to the latest release now, and shows how to keep Claude Code on `@latest`. |
| `workflow-companion auto-update on\|off` | Whether the scheduled jobs update themselves (on by default). |
| `workflow-companion wake-on` | Starts a Claude Code session on its own when work for its name arrives. See above. |
| `workflow-companion wake-off` | Stops that. Work waits until you ask Claude here. |
| `workflow-companion wake` | One check of the queue. The scheduled job runs this. |
| `workflow-companion signout` | Deletes the sign-in, cached data and both scheduled jobs. |
| `workflow-companion wake-on` | Starts a Claude Code session on its own when work for its name arrives. See above. |
| `workflow-companion wake-off` | Stops that. Work waits until you ask Claude here. |
| `workflow-companion wake` | One check of the queue. The scheduled job runs this. |
| `workflow-companion signout` | Deletes the sign-in, cached data and both scheduled jobs. |

## Worth knowing

- **Something has to be answering.** A command sent while nothing is waits in
  iCloud and runs when WorkFlow next looks. The tool says so, and its receipt
  shows later in `workflow_state`.
- **Reads come from a snapshot.** WorkFlow publishes it a few seconds after each
  change, so a read straight after a write can lag slightly.
- **Files go through your iCloud (1.6).** Attaching a file, filing a document
  into a project or adding a new version uploads the file to your own iCloud;
  WorkFlow 5.3 or later on the answering Mac or iPhone attaches it and then
  deletes the uploaded copy. Up to 50 MB a file. An older WorkFlow ignores the
  upload and reports the file as missing.
- **The token is a password.** `~/.workflow-companion/token.txt` opens your
  WorkFlow data in iCloud. Apple replaces it on every request, and the
  companion saves each replacement at once. Several Claude sessions on one
  computer can share it: they take turns. Don't copy it to another machine.
  Each computer should run its own `setup`.
- **Keep-alive.** Apple ends a sign-in left unused for somewhere between 9 and
  14 hours. The companion renews it every two hours while Claude has it
  running. Setup also schedules `workflow-companion keepalive` every three
  hours: in Task Scheduler on Windows (it runs without a console window) or
  in cron elsewhere. `signout` removes that schedule; `--no-schedule` skips it.
- **"Sign in again"** means Apple ended the session (HTTP 401/421), for
  example after the computer was off for a long time. Run `setup` again.

## Tools

The same 29 tools as the Mac's Agent Bridge MCP server, including:
`workflow_queue`, `workflow_get_task`, `workflow_comment`,
`workflow_set_status_line`, `workflow_check_subtasks`, `workflow_update_task`,
`workflow_create_task`, `workflow_list_notes`, `workflow_reply_note`,
`workflow_list_projects`, `workflow_list_documents`, `workflow_update_document`,
`workflow_draft_email` and `workflow_state`.

© Opticell Limited · <https://www.opticell-limited.com/companion>

## Source and licence

`src/index.js` is the whole server: one file, Node 18 or later, no
dependencies. It is MIT licensed (see `LICENSE`). The published npm package
is the same file with WorkFlow's CloudKit API token filled in at build time
(the token is not a secret: it only lets a signed-in user reach their own
data). Run from source, `setup` asks for it with `--api-token`.

The `Dockerfile` runs the server over stdio. MCP directories use it to check
that the server starts and lists its tools, which it does without signing in.

