#!/bin/bash
# Offline test of the companion's iCloud mode. mock.js stands in for CloudKit
# Web Services (rotating the token on every answer and refusing a stale one,
# as Apple does); mac.js stands in for WorkFlow on the Mac, applying commands
# and writing receipts. Nothing touches the network or the real ~/.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
W="$(mktemp -d)"; trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$W"' EXIT
# The server under test: WorkFlow's copy, or src/ in the public repo.
SERVER_DEFAULT="$HERE/../../workflow-mcp/index.js"; [ -f "$SERVER_DEFAULT" ] || SERVER_DEFAULT="$HERE/../src/index.js"
export HOME="$W/home" MOCK_STATE="$W/state.json" SERVER="${SERVER:-$SERVER_DEFAULT}"
# Never touch the real crontab or Task Scheduler from a test.
export WF_NO_SCHEDULE=1
# Nor show real notifications: they're written here instead.
export WF_NOTIFY_LOG="$W/notify.log"
mkdir -p "$HOME"; cd "$HERE"; node init.js
# 2.2: the daily assistant's brief and check-in decisions, offline.
node daily.js | sed 's/^/  /' || fail=1
fail=0; check() { if eval "$2"; then echo "pass  $1"; else echo "FAIL  $1"; fail=1; fi; }
st() { node -e "const s=require(process.env.MOCK_STATE); console.log($1)"; }

node -r ./mock.js "$SERVER" setup --api-token A --web-token tok0 > "$W/setup.out"
check "setup signs in and saves the successor token" "grep -q 'Signed in' $W/setup.out && [ \"\$(cat $HOME/.workflow-companion/token.txt)\" = \"\$(st s.token)\" ]"

node mac.js & MAC=$!
head -c 4096 /dev/urandom > "$W/report.pdf"
node drive.js '[["workflow_list_tasks"],["workflow_comment",{"task":"quarterly","text":"hi"}],["workflow_attach_file",{"task":"T1","file":"'"$W"'/report.pdf"}]]' > "$W/s1.out"
check "reads the snapshot" "grep -q '#1 ok  To Do' $W/s1.out"
check "a comment round-trips" "grep -q '#2 ok  \[ok\] did add_comment' $W/s1.out"
node drive.js '[["workflow_comment",{"task":"quarterly","react":"👀"}]]' > "$W/s1r.out"
check "a reaction goes through workflow_comment as a react command" "grep -q '#1 ok  \[ok\] did react' $W/s1r.out && node -e \"const s=require(process.env.MOCK_STATE); const c=s.applied.find(c=>c.op=='react')||{}; process.exit(c.emoji=='👀'&&c.taskID?0:1)\""
node drive.js '[["workflow_propose",{"task":"quarterly","action":"update","due":"2026-11-07","summary":"Move it to next week"}],["workflow_propose",{"task":"quarterly","action":"delete"}]]' > "$W/sp.out"
check "a proposal goes as a propose command carrying the change (5.6)" "grep -q '#1 ok  \[ok\] did propose' $W/sp.out && node -e \"const s=require(process.env.MOCK_STATE); const ps=s.applied.filter(c=>c.op=='propose'); const [u,d]=ps; process.exit(ps.length==2&&u.text=='Move it to next week'&&u.proposal.op=='update_task'&&u.proposal.dueDate=='2026-11-07'&&u.proposal.taskID==u.taskID&&d.proposal.op=='delete_task'?0:1)\""
attached() { node -e "const s=require(process.env.MOCK_STATE); const c=s.applied.find(c=>c.op=='attach_file')||{}; console.log([c.uploadFound, c.uploadBytes, c.fileName, Object.keys(s.records).filter(k=>k.startsWith('upload-')).length].join(' '))"; }
check "a file goes up through iCloud and the command names it" "grep -q '#3 ok  \\[ok\\] did attach_file' $W/s1.out && [ \"\$(attached | cut -d' ' -f1-3)\" = 'true 4096 report.pdf' ]"
check "the upload is gone once the command is applied" "[ \"\$(attached | cut -d' ' -f4)\" = 0 ]"
mkfile -n 51m "$W/huge.bin" 2>/dev/null || truncate -s 51M "$W/huge.bin"
node drive.js '[["workflow_attach_file",{"task":"T1","file":"'"$W"'/huge.bin"}]]' > "$W/s2.out"
check "a file over 50 MB is refused before anything is uploaded" "grep -q 'takes files up to 50 MB' $W/s2.out && [ \"\$(st 'Object.keys(s.uploads||{}).length')\" = 1 ]"

C='[["workflow_comment",{"task":"T1","text":"a"}],["workflow_comment",{"task":"T1","text":"b"}]]'
node drive.js "$C" > "$W/a.out" & A=$!; node drive.js "$C" > "$W/b.out" & B=$!; node drive.js "$C" > "$W/c.out"; wait $A $B
check "three processes at once: every receipt reaches its sender" "[ \$(cat $W/a.out $W/b.out $W/c.out | grep -c 'did add_comment') = 6 ]"
check "no token was ever refused" "[ \"\$(st s.rejected)\" = 0 ] && [ \"\$(cat $HOME/.workflow-companion/token.txt)\" = \"\$(st s.token)\" ]"
receipts_left() { node -e "const s=require(process.env.MOCK_STATE);console.log(Object.keys(s.records).filter(k=>k.startsWith('receipt-')).length)"; }
check "receipts are deleted from iCloud" "[ \"\$(receipts_left)\" = 0 ]"
kill $MAC

node -e "const f=process.env.MOCK_STATE,s=require(f);s.noZone=true;require('fs').writeFileSync(f,JSON.stringify(s))"
node drive.js '[["workflow_ping"]]' > "$W/z.out"
check "Cloud Bridge off is explained" "grep -q \"isn't switched on in WorkFlow\" $W/z.out"
node -e "const f=process.env.MOCK_STATE,s=require(f);s.noZone=false;s.expired=true;require('fs').writeFileSync(f,JSON.stringify(s))"
node drive.js '[["workflow_queue"]]' > "$W/e.out"
check "an ended sign-in says to run setup" "grep -q 'sign-in has ended (HTTP 421)' $W/e.out"
# Names: a companion called "Server" gets its own queue and signs as itself.
node -e "const f=process.env.MOCK_STATE,s=require(f);s.expired=false;s.rejected=0;s.token='n0';require('fs').writeFileSync(f,JSON.stringify(s))"
rm -rf "$HOME/.workflow-companion"
node -r ./mock.js "$SERVER" setup --api-token A --web-token n0 --name Server > /dev/null
node mac.js & MAC=$!
node drive.js '[["workflow_queue"],["workflow_comment",{"task":"T2","text":"on it"}]]' > "$W/n1.out"
kill $MAC
check "queue: assigned + @mention + note, not shared, not Claude's" "grep -q 'Rotate the backups.*assigned to Server' $W/n1.out && grep -q 'Check the dashboards.*@Server in a comment' $W/n1.out && grep -q 'note: Ideas' $W/n1.out && ! grep -q 'Shared thing' $W/n1.out && ! grep -q 'Mac work' $W/n1.out && ! grep -q 'note: Other' $W/n1.out"
check "commands carry the companion's name" "[ \"\$(st 's.applied.at(-1).agentName')\" = Server ]"
node -r ./mock.js "$SERVER" setup --api-token A --web-token x --name Claude > "$W/n2.out" 2>&1
check "the name Claude is refused" "grep -q 'not \"Claude\"' $W/n2.out"

# One name, one computer: "Busy" already belongs to OTHER-PC.
node -r ./mock.js "$SERVER" setup --api-token A --web-token "$(st s.token)" --name Busy > "$W/c1.out" 2>&1
check "a name another computer uses is refused" "grep -q 'already Claude on OTHER-PC' $W/c1.out && [ \"\$(node -e 'console.log(require(process.env.HOME+\"/.workflow-companion/config.json\").agentName)')\" != Busy ]"
node -r ./mock.js "$SERVER" setup --api-token A --web-token "$(st s.token)" --name Busy --takeover > "$W/c2.out" 2>&1
node -r ./mock.js "$SERVER" status > "$W/c3.out" 2>&1
check "--takeover allows it, and status warns about the clash" "grep -q 'Signed in' $W/c2.out && grep -q 'WARNING     OTHER-PC also answers' $W/c3.out"

# The same rule for every command: a name another computer answers to is
# refused at send time too (Claude Desktop never runs setup), unless this
# computer took the name over at setup.
cfg() { node -e "const f=process.env.HOME+'/.workflow-companion/config.json',c=require(f);$1;require('fs').writeFileSync(f,JSON.stringify(c))"; }
cfg "delete c.takeoverFrom"
WF_AGENT_NAME=Busy node drive.js '[["workflow_comment",{"task":"T1","text":"x"}]]' > "$W/b1.out"
check "a Desktop name that clashes can't send" "grep -q 'Not sent: \"Busy\" is also the name of Claude on OTHER-PC' $W/b1.out && grep -q 'Name in WorkFlow' $W/b1.out"
cfg "c.takeoverFrom='OTHER-PC'"
node mac.js & MAC=$!
node drive.js '[["workflow_comment",{"task":"T1","text":"after takeover"}]]' > "$W/b2.out"
kill $MAC
check "after --takeover this computer can send as Busy" "grep -q '#1 ok  \[ok\] did add_comment' $W/b2.out && [ \"\$(st 's.applied.at(-1).agentName')\" = Busy ]"

# An unanswered command waits the full ~40 s in iCloud mode, whatever short
# timeout the tool passes for the folder bridge (a 10 s cut-off slipped in
# once and only a real iPhone showed it).
node -e "const f=process.env.MOCK_STATE,s=require(f);s.expired=false;require('fs').writeFileSync(f,JSON.stringify(s))"
t0=$(date +%s); node drive.js '[["workflow_comment",{"task":"T1","text":"nobody home"}]]' > "$W/w1.out"; t1=$(date +%s)
check "a normal command waits the full time before saying pending" "grep -q 'within 40 s' $W/w1.out && [ \$(( t1 - t0 )) -ge 38 ]"

# Keep-alive: renews the sign-in; the schedule goes into (a fake) crontab and
# comes out again on signout, leaving other entries alone.
node -e "const f=process.env.MOCK_STATE,s=require(f);s.expired=false;require('fs').writeFileSync(f,JSON.stringify(s))"
before=$(st s.token)
node -r ./mock.js "$SERVER" keepalive; ka=$?
check "keepalive renews the sign-in and logs it" "[ $ka = 0 ] && [ \"\$(st s.token)\" != \"$before\" ] && grep -q ' ok' $HOME/.workflow-companion/keepalive.log"
mkdir -p "$W/bin"; printf '%s\n' '#!/bin/bash' 'F="$(dirname "$0")/crontab.txt"' 'if [ "$1" = "-l" ]; then cat "$F" 2>/dev/null || exit 1; else cat > "$F"; fi' > "$W/bin/crontab"; chmod +x "$W/bin/crontab"
echo "0 1 * * * other job" > "$W/bin/crontab.txt"
PATH="$W/bin:$PATH" WF_NO_SCHEDULE= node -r ./mock.js "$SERVER" setup --api-token A --web-token "$(st s.token)" --name Server --takeover > "$W/k1.out" 2>&1
check "setup schedules the keep-alive in cron" "grep -q 'Keep-alive: cron, every 3 hours' $W/k1.out && grep -q 'workflow-companion.js\" keepalive' $W/bin/crontab.txt && grep -q 'other job' $W/bin/crontab.txt && [ -f $HOME/.workflow-companion/workflow-companion.js ]"
PATH="$W/bin:$PATH" node "$SERVER" signout > /dev/null
check "signout removes it and keeps other cron jobs" "! grep -q keepalive $W/bin/crontab.txt && grep -q 'other job' $W/bin/crontab.txt"

# Claude Desktop: the token arrives in WF_SIGNIN_TOKEN, is taken in once, and
# the rotating copy on disk wins after that.
node -e "const f=process.env.MOCK_STATE,s=require(f);s.expired=false;s.rejected=0;s.token='desk0';require('fs').writeFileSync(f,JSON.stringify(s))"
rm -rf "$HOME/.workflow-companion"
WF_SIGNIN_TOKEN=desk0 node drive.js '[["workflow_list_tasks"],["workflow_queue"]]' > "$W/d1.out"
WF_SIGNIN_TOKEN=desk0 node drive.js '[["workflow_list_tasks"]]' > "$W/d2.out"
check "Desktop token is taken in, then the rotated one is kept" "grep -q '#2 ok' $W/d1.out && grep -q '#1 ok  To Do' $W/d2.out && [ \"\$(st s.rejected)\" = 0 ]"
node -e "const f=process.env.MOCK_STATE,s=require(f);s.expired=true;require('fs').writeFileSync(f,JSON.stringify(s))"
WF_SIGNIN_TOKEN=desk0 node drive.js '[["workflow_queue"]]' > "$W/d3.out"
check "Desktop users are told to paste a fresh token into the setting" "grep -q 'Sign-in token' $W/d3.out"

# Wake: @Name from the app starts a Claude Code session with nobody at the
# computer. A fake `claude` records what it was given; FAKE_SEND makes it
# send a comment (as a real session would), FAKE_EXIT / FAKE_SLEEP make it fail.
node -e "const f=process.env.MOCK_STATE,s=require(f);s.expired=false;s.rejected=0;s.token='w0';s.applied=[];require('fs').writeFileSync(f,JSON.stringify(s))"
rm -rf "$HOME/.workflow-companion"
node -r ./mock.js "$SERVER" setup --api-token A --web-token w0 --name Server > "$W/wk0.out" 2>&1
# Start the wake tests clean: commands left unanswered by earlier tests (and
# setup's own ping) would otherwise be applied mid-way and muddle the counts.
node -e "const f=process.env.MOCK_STATE,s=require(f);for(const[k,r]of Object.entries(s.records))if(r.recordType==='BridgeCommand')delete s.records[k];s.applied=[];require('fs').writeFileSync(f,JSON.stringify(s))"
check "setup tells you how to switch waking on" "grep -q 'workflow-companion wake-on' $W/wk0.out"
{
  echo '#!/bin/bash'
  echo "echo \"\$*\" > '$W/claude.args'; cat > '$W/claude.prompt'; echo run >> '$W/claude.runs'"
  echo '[ -n "${FAKE_SLEEP:-}" ] && sleep "$FAKE_SLEEP"'
  echo "[ -n \"\${FAKE_SEND:-}\" ] && node '$HERE/drive.js' '[[\"workflow_comment\",{\"task\":\"T3\",\"text\":\"picked up\"}]]' > /dev/null"
  # 1.9: answer a self-test the way Claude would, by setting the status line.
  echo "if grep -q 'scheduled self-test' '$W/claude.prompt' && [ -n \"\${FAKE_CANARY_FAIL:-}\" ]; then echo \"You've reached your usage limit\"; exit 1; fi; if grep -q 'scheduled self-test' '$W/claude.prompt' && [ -z \"\${FAKE_EXIT:-}\" ]; then T=\$(sed -n 's/.*with task \"\\([^\"]*\\)\".*/\\1/p' '$W/claude.prompt'); N=\$(sed -n 's/.*status_line \"self-test \\([0-9a-f]*\\)\".*/\\1/p' '$W/claude.prompt'); node '$HERE/drive.js' \"[[\\\"workflow_update_task\\\",{\\\"task\\\":\\\"\$T\\\",\\\"status_line\\\":\\\"self-test \$N\\\"}]]\" > /dev/null; fi"
  echo 'exit ${FAKE_EXIT:-0}'
} > "$W/bin/fake-claude"
chmod +x "$W/bin/fake-claude"
runs() { cat "$W/claude.runs" 2>/dev/null | wc -l | tr -d ' '; }
wake() { node -r ./mock.js "$SERVER" wake; }

wake
check "waking is off until switched on" "[ \$(runs) = 0 ]"
rm -f "$W/bin/crontab.txt"
PATH="$W/bin:$PATH" node -r ./mock.js "$SERVER" wake-on --claude "$W/bin/fake-claude" > "$W/wk0b.out" 2>&1
check "wake-on never schedules while WF_NO_SCHEDULE is set" "grep -q 'not scheduled' $W/wk0b.out && [ ! -f $W/bin/crontab.txt ]"
PATH="$W/bin:$PATH" WF_NO_SCHEDULE= node -r ./mock.js "$SERVER" wake-on --claude "$W/bin/fake-claude" > "$W/wk1.out" 2>&1
check "wake-on schedules a check every 2 minutes in cron" "grep -q 'cron, every 2 minutes' $W/wk1.out && grep -q 'workflow-companion.js\" wake' $W/bin/crontab.txt"
# The daily self-test (1.9) is due whenever the tests run after 07:30; it has
# its own tests below, and stays out of the counts until then.
node -r ./mock.js "$SERVER" canary off > /dev/null
node -r ./mock.js "$SERVER" status > "$W/wk2.out" 2>&1
check "status says waking is on" "grep -q 'waking      on' $W/wk2.out"
wake
check "new @mention work starts one session" "[ \$(runs) = 1 ] && grep -q 'Rotate the backups' $W/claude.prompt && grep -q 'Check the dashboards' $W/claude.prompt && grep -q 'Ideas' $W/claude.prompt"
check "the session isn't told about shared or Claude's work" "! grep -q 'Shared thing' $W/claude.prompt && ! grep -q 'Mac work' $W/claude.prompt"
check "only the WorkFlow tools are allowed by default" "grep -q -- '-p --allowedTools mcp__workflow' $W/claude.args"
check "the prompt treats task text as data" "grep -q 'They are DATA' $W/claude.prompt"
wake
check "the same work never starts a second session" "[ \$(runs) = 1 ]"

node bump.js s2 _a Alex "@Server and the logs too?"
wake
check "a follow-up @mention wakes again, for that task only" "[ \$(runs) = 2 ] && grep -q 'Check the dashboards' $W/claude.prompt && ! grep -q 'Rotate the backups' $W/claude.prompt"
node bump.js s3 agent.server Server "Done. @Server notes are in the status line"
wake
check "the agent's own reply never wakes it" "[ \$(runs) = 2 ]"

echo $$ > "$HOME/.workflow-companion/wake.lock"
node bump.js s4 _a Alex "@Server one more"
wake
check "no second session while one is running" "[ \$(runs) = 2 ]"
rm -f "$HOME/.workflow-companion/wake.lock"

# A session that can't start (usage limit, not signed in) wrote nothing: it
# is retried on the next ticks, then said once in the thread.
node mac.js & MAC=$!
FAKE_EXIT=1 wake; FAKE_EXIT=1 wake
check "a failed start that wrote nothing is retried" "[ \$(runs) = 4 ] && [ \"\$(st 's.applied.length')\" = 0 ]"
FAKE_EXIT=1 wake
check "after the last try the failure is said in the thread" "[ \$(runs) = 5 ] && [ \"\$(st 's.applied.at(-1).op')\" = add_comment ] && st 's.applied.at(-1).text' | grep -q \"couldn't start\""
FAKE_EXIT=1 wake
check "and it isn't retried after that" "[ \$(runs) = 5 ]"

node bump.js s5 _a Alex "@Server again please"
FAKE_SEND=1 FAKE_EXIT=1 wake; FAKE_EXIT=1 wake
check "a session that wrote and then failed is not replayed" "[ \$(runs) = 6 ] && st 's.applied.at(-1).text' | grep -q 'ended early'"

node bump.js s6 _a Alex "@Server slow one"
t0=$(date +%s); FAKE_SLEEP=30 WF_WAKE_MAX_SECONDS=2 wake; t1=$(date +%s)
check "a stuck session is stopped at the time limit and reported" "[ \$(( t1 - t0 )) -lt 25 ] && st 's.applied.at(-1).text' | grep -q 'I was stopped'"
kill $MAC

# Assistant hand-offs (1.6): Claude's @Server as the newest comment wakes it,
# within a limit; a person writing again resets the count.
before=$(runs)
node bump.js s7 agent.claude Claude "@Server please verify the cert"
wake
check "another assistant's @mention wakes it" "[ \$(runs) = \$((before + 1)) ]"
node bump.js s8 agent.server Server "done @Claude"
node bump.js s9 agent.claude Claude "@Server one more"
node bump.js s10 agent.server Server "ok @Claude"
node bump.js s11 agent.claude Claude "@Server and again"
wake
check "the fourth hand-off in a row is refused" "[ \$(runs) = \$((before + 1)) ]"
node bump.js s12 _a Alex "carry on"
node bump.js s13 agent.claude Claude "@Server go ahead"
wake
check "a person writing again lets hand-offs resume" "[ \$(runs) = \$((before + 2)) ]"

# 1.6.2: on a task ASSIGNED to this agent, another assistant's @mention wakes
# it too. Before, only a person's comment did (Jarvis, 14 Oct: opticell's
# "@Jarvis" on a task assigned to Jarvis started nothing).
node bump.js s14 agent.claude Claude "@Server can you take this on?" T2
wake
check "an assistant's @mention on an assigned task wakes it" "[ \$(runs) = \$((before + 3)) ] && grep -q 'Rotate the backups' $W/claude.prompt"
node bump.js s15 agent.claude Claude "FYI, no action needed" T2
wake
check "an assistant's comment without a mention doesn't" "[ \$(runs) = \$((before + 3)) ]"

# 1.7 (WorkFlow 5.4): house rules, watches, hand-offs and activity.
snapset() { node -e "const fs=require('fs'),f=process.env.MOCK_STATE;let snap;try{snap=JSON.parse(fs.readFileSync(f+'.snap','utf8'))}catch(_){snap=JSON.parse(JSON.stringify(require('./mock.js').snap))};const t=id=>snap.tasks.find(x=>x.id===id);$1;fs.writeFileSync(f+'.snap',JSON.stringify(snap));const s=JSON.parse(fs.readFileSync(f,'utf8'));s.records.snapshot.fields.sha.value='$2';fs.writeFileSync(f,JSON.stringify(s))"; }
activity() { node -e "const s=require(process.env.MOCK_STATE);const r=s.records['companion-server'];const a=r&&r.fields.activity;console.log(a?JSON.parse(a.value).state:'none')"; }
snapset "snap.houseRules='Keep replies short.\nJarvis owns the server.'" h1
node mac.js & MAC=$!
node drive.js '[["workflow_queue"],["workflow_house_rules"],["workflow_watch",{"task":"T2","minutes":30,"note":"backup finished?"}],["workflow_watch",{"task":"T2"}],["workflow_hand_off",{"task":"T1","to":"Claude","note":"please verify"}],["workflow_hand_off",{"task":"T5","to":"Bob"}]]' > "$W/r1.out"
kill $MAC
check "the queue starts with the house rules" "grep -q 'HOUSE RULES' $W/r1.out && grep -q 'Jarvis owns the server' $W/r1.out"
check "workflow_house_rules returns them" "grep -q '#2 ok  Keep replies short' $W/r1.out"
watchcmd() { node -e "const s=require(process.env.MOCK_STATE);const c=s.applied.find(c=>c.watchUntil);console.log(c?[c.taskID,Math.round((Date.parse(c.watchUntil)-Date.now())/60000),c.watchNote].join('|'):'none')"; }
check "a watch is sent as update_task with its time and reason" "watchcmd | grep -q '^T2|[23][0-9]|backup finished?$' && grep -q 'woken about this task' $W/r1.out"
check "a watch with no time is refused" "grep -q '#4 ERR Give minutes' $W/r1.out"
handoff() { node -e "const s=require(process.env.MOCK_STATE);console.log(JSON.stringify(s.applied.filter(c=>c.taskID==='$1').map(c=>c.assignee||c.text)))"; }
check "a hand-off to an assistant reassigns it and @mentions it" "[ \"\$(handoff T1)\" = '[\"Claude\",\"@Claude handing this over to you. please verify\"]' ]"
check "a hand-off to a person has no @mention" "[ \"\$(handoff T5)\" = '[\"Bob\",\"Handed to Bob.\"]' ]"

before=$(runs)
snapset "t('T1').watch={agent:'Server',until:new Date(Date.now()+3600000).toISOString()}" h2
wake
check "a watch that isn't due wakes nothing" "[ \$(runs) = \$before ]"
snapset "t('T2').watch={agent:'Server',until:new Date(Date.now()-3000).toISOString(),note:'backups done?'}" h3
wake
check "a watch that has come due wakes it, saying why" "[ \$(runs) = \$((before + 1)) ] && grep -q 'your watch came due (backups done?)' $W/claude.prompt && grep -q 'HOUSE RULES' $W/claude.prompt"
check "after a session it reports itself idle" "[ \"\$(activity)\" = idle ]"
wake
check "a watch fires once" "[ \$(runs) = \$((before + 1)) ]"
node bump.js s16 _a Alex "@Server status?"
node mac.js & MAC=$!
FAKE_EXIT=1 wake
kill $MAC
check "a session that can't start reports that it needs attention" "[ \"\$(activity)\" = attention ]"
node -e "const f=process.env.MOCK_STATE,s=require(f);s.rejectFields=['activity'];delete s.records['companion-server'];require('fs').writeFileSync(f,JSON.stringify(s))"
node bump.js s17 _a Alex "@Server once more"
wake
check "before Production has the field, presence is still written without it" "[ \"\$(activity)\" = none ] && [ \"\$(st 's.records[\"companion-server\"].fields.appVersion.value')\" != undefined ] && grep -q activityFieldMissingUntil $HOME/.workflow-companion/config.json"
node -e "const f=process.env.MOCK_STATE,s=require(f);s.rejectFields=[];require('fs').writeFileSync(f,JSON.stringify(s))"
node -e "const f=process.env.HOME+'/.workflow-companion/config.json',c=require(f);delete c.activityFieldMissingUntil;require('fs').writeFileSync(f,JSON.stringify(c))"

# 1.8: monitors, approvals, session reports, the inbox folder, notifications.
export WF_NOTIFY_LOG="$W/notify.log"
node -e "
const http=require('http'),fs=require('fs');
http.createServer((q,r)=>{const bad=fs.existsSync('$W/site-down');r.writeHead(bad?503:200);r.end(bad?'down':'all good');}).listen(0,'127.0.0.1',function(){fs.writeFileSync('$W/site-port',String(this.address().port))});
" & SITE=$!
while [ ! -s "$W/site-port" ]; do sleep 0.2; done; PORT=$(cat "$W/site-port")
node mac.js & MAC=$!
node -r ./mock.js "$SERVER" monitor add --name site --http "http://127.0.0.1:$PORT/" --expect "all good" --task T2 --every 2 --wake > "$W/m1.out" 2>&1
check "a monitor is added and checked straight away" "grep -q 'Monitor “site” added: OK now (HTTP 200)' $W/m1.out"
before=$(runs)
wake
check "a healthy monitor posts nothing and wakes nothing" "[ \$(runs) = \$before ] && ! st 'JSON.stringify(s.applied)' | grep -q 'Monitor'"
touch "$W/site-down"
node -e "const f=process.env.HOME+'/.workflow-companion/monitors.json',l=require(f);l[0].checkedAt=new Date(0).toISOString();require('fs').writeFileSync(f,JSON.stringify(l))"
wake
check "a monitor that fails posts on its task, notifies, and wakes Claude once" "st 'JSON.stringify(s.applied)' | grep -q 'Monitor “site” FAILED: HTTP 503' && grep -q 'WorkFlow · site' $W/notify.log && [ \$(runs) = \$((before + 1)) ] && grep -q 'monitor “site” changed: FAILED' $W/claude.prompt"
node drive.js '[["workflow_monitor",{"action":"add","name":"x","type":"command","target":"rm -rf /tmp/x"}],["workflow_monitor",{"action":"add","name":"web","type":"port","target":"127.0.0.1:'"$PORT"'","task":"T2"}],["workflow_monitor",{"action":"list"}],["workflow_request_approval",{"task":"T2","action":"say hi","command":"echo hi"}]]' > "$W/m2.out"
check "an assistant can't add a command monitor" "grep -q '#1 ERR Only the person at this computer' $W/m2.out"
check "an assistant can add a port monitor" "grep -q '#2 ok  Monitor “web” added' $W/m2.out && grep -q 'web  \[port' $W/m2.out"
check "approvals are off until the person switches them on" "grep -q '#4 ERR Approvals are off' $W/m2.out"

node -r ./mock.js "$SERVER" approvals on > /dev/null
node drive.js '[["workflow_request_approval",{"task":"T2","action":"write a file","command":"echo approved-run > \"'"$W"'/ran.txt\""}]]' > "$W/a1.out"
CODE=$(sed -n 's/.*Asked for approval \([A-Z0-9]*\)\..*/\1/p' "$W/a1.out")
check "an approval request posts the exact command and a code" "[ -n \"$CODE\" ] && st 'JSON.stringify(s.applied.at(-1))' | grep -q \"approve $CODE\" && st 'JSON.stringify(s.applied.at(-1))' | grep -q 'ran.txt'"
node bump.js s20 agent.claude Claude "approve $CODE" T2
node drive.js '[["workflow_check_approval",{"code":"'"$CODE"'"}],["workflow_run_approved",{"code":"'"$CODE"'"}]]' > "$W/a2.out"
check "another assistant can't approve" "grep -q \"#1 ok  $CODE: pending\" $W/a2.out && grep -q '#2 ERR .*is pending, not approved' $W/a2.out && [ ! -f $W/ran.txt ]"
before=$(runs)
node bump.js s21 _a Alex "approve $CODE" T2
wake
check "the person's approval wakes the session, saying so" "[ \$(runs) = \$((before + 1)) ] && grep -q \"approval request $CODE was approved by Alex\" $W/claude.prompt"
node drive.js '[["workflow_run_approved",{"code":"'"$CODE"'"}],["workflow_run_approved",{"code":"'"$CODE"'"}]]' > "$W/a3.out"
check "the approved command runs, exactly once" "grep -q '#1 ok  Ran $CODE' $W/a3.out && grep -q approved-run $W/ran.txt && grep -q '#2 ERR .*already ran' $W/a3.out"

before=$(runs)
node bump.js s22 _a Alex "@Server write something" T3
FAKE_SEND=1 wake
check "a session that did something attaches a report to its task" "st 'JSON.stringify(s.applied.filter(c=>c.op===\"attach_file\").map(c=>c.displayName))' | grep -q 'Session report'"
node -r ./mock.js "$SERVER" reports off > /dev/null
n_reports=$(st 's.applied.filter(c=>c.op==="attach_file").length')
node bump.js s23 _a Alex "@Server again" T3
FAKE_SEND=1 wake
check "with reports off, none is attached" "[ \"\$(st 's.applied.filter(c=>c.op===\"attach_file\").length')\" = \"$n_reports\" ]"

mkdir -p "$W/inbox/Ops"
node -r ./mock.js "$SERVER" inbox-on --folder "$W/inbox" > "$W/i1.out"
echo "quarterly figures" > "$W/inbox/Q3 report.txt"; echo "x" > "$W/inbox/Ops/runbook.md"; echo "y" > "$W/inbox/new.part"
touch -t 202601010000 "$W/inbox/Q3 report.txt" "$W/inbox/Ops/runbook.md" "$W/inbox/new.part"
wake
check "dropped files become tasks with the file attached" "st 'JSON.stringify(s.applied)' | grep -q '\"title\":\"Q3 report\"' && st 'JSON.stringify(s.applied.filter(c=>c.op===\"attach_file\").map(c=>c.displayName))' | grep -q 'Q3 report.txt'"
check "a subfolder files into that project" "st 'JSON.stringify(s.applied.filter(c=>c.title===\"runbook\"))' | grep -q '\"project\":\"Ops\"'"
check "filed files move to Filed; partial downloads are left" "ls $W/inbox/Filed/*/ | grep -q 'Q3 report.txt' && [ -f $W/inbox/new.part ] && [ ! -f \"$W/inbox/Q3 report.txt\" ]"
kill $MAC $SITE

node -e "const f=process.env.MOCK_STATE,s=require(f);s.expired=true;require('fs').writeFileSync(f,JSON.stringify(s))"
node -r ./mock.js "$SERVER" keepalive > /dev/null 2>&1
check "a sign-in that ended says so on this computer" "grep -q 'sign-in on .* has ended' $W/notify.log"
node -r ./mock.js "$SERVER" keepalive > /dev/null 2>&1
check "and only once, not every tick" "[ \$(grep -c 'has ended' $W/notify.log) = 1 ]"
node -e "const f=process.env.MOCK_STATE,s=require(f);s.expired=false;require('fs').writeFileSync(f,JSON.stringify(s))"
node -r ./mock.js "$SERVER" notifications off > /dev/null
lines=$(wc -l < "$W/notify.log"); node -r ./mock.js "$SERVER" notify-test > /dev/null
check "notifications can be switched off" "[ \$(wc -l < $W/notify.log) = $lines ]"
node -r ./mock.js "$SERVER" notifications on > /dev/null
node -r ./mock.js "$SERVER" inbox-off > /dev/null
node -e "require('fs').writeFileSync(process.env.HOME+'/.workflow-companion/monitors.json','[]')"

# Versions (1.6.1): presence, the latest-release check, and self-update.
CUR=$(sed -n 's/^const SERVER_INFO = { name: "workflow", version: "\([0-9.]*\)" };$/\1/p' "$SERVER")
presence() { node -e "const s=require(process.env.MOCK_STATE);const r=s.records['companion-server'];console.log(r?r.fields.appVersion.value+' '+r.fields.device.value:'none')"; }
check "setup reported this companion's version to iCloud" "[ \"\$(presence | cut -d' ' -f1)\" = \"$CUR\" ]"
SAVED="$HOME/.workflow-companion/workflow-companion.js"
savedver() { sed -n 's/^const SERVER_INFO = { name: "workflow", version: "\([0-9.]*\)" };$/\1/p' "$SAVED"; }
release() {   # release <version> [bad]: a package on the fake registry
  rm -rf "$W/pkg"; mkdir -p "$W/pkg/package"
  sed "s/^const SERVER_INFO = { name: \"workflow\", version: \"[0-9.]*\" };$/const SERVER_INFO = { name: \"workflow\", version: \"$1\" };/" "$SERVER" > "$W/pkg/package/index.js"
  tar czf "$MOCK_STATE.tgz" -C "$W/pkg" package
  sum="sha512-$(openssl dgst -sha512 -binary "$MOCK_STATE.tgz" | base64 | tr -d '\n')"
  [ "${2:-}" = bad ] && sum="sha512-AAAA"
  printf '{"version":"%s","dist":{"tarball":"https://registry.mock/rel.tgz","integrity":"%s"}}' "$1" "$sum" > "$MOCK_STATE.release"
  cfg "delete c.latestRelease"
}
[ -f "$SAVED" ] || cp "$SERVER" "$SAVED"
release 9.9.9
node -r ./mock.js "$SERVER" status > "$W/v1.out" 2>&1
check "status says an update is available" "grep -q 'UPDATE AVAILABLE: 9.9.9' $W/v1.out"
release 9.9.9 bad
node -r ./mock.js "$SERVER" update > "$W/v2.out" 2>&1
check "a release whose checksum doesn't match npm's is refused" "grep -q \"checksum didn't match\" $W/v2.out && [ \"\$(savedver)\" = \"$CUR\" ]"
release 9.9.9
node -r ./mock.js "$SERVER" update > "$W/v3.out" 2>&1
check "update replaces the scheduled copy with the verified release" "grep -q 'updated from $CUR to 9.9.9' $W/v3.out && [ \"\$(savedver)\" = 9.9.9 ] && node --check $SAVED"
check "update prints the @latest Claude Code registration" "grep -q 'npx -y @opticell/workflow-companion@latest' $W/v3.out"
node -r ./mock.js "$SERVER" auto-update off > /dev/null
release 9.9.10
node -r ./mock.js "$SERVER" keepalive
check "with auto-update off the scheduled run leaves it alone" "[ \"\$(savedver)\" = 9.9.9 ]"
node -r ./mock.js "$SERVER" auto-update on > /dev/null
cfg "delete c.latestRelease"
node -r ./mock.js "$SERVER" keepalive
check "with auto-update on the scheduled run updates itself" "[ \"\$(savedver)\" = 9.9.10 ] && grep -q 'updated from 9.9.9 to 9.9.10' $HOME/.workflow-companion/keepalive.log"
rm -f "$MOCK_STATE.release" "$MOCK_STATE.tgz"

# 1.9: the daily self-test.
canary() { PATH="$W/bin:$PATH" node -r ./mock.js "$SERVER" canary "$@"; }
node -r ./mock.js "$SERVER" canary on > /dev/null
applied_json() { st 'JSON.stringify(s.applied)'; }
node mac.js & MAC=$!
canary > "$W/c1.out" 2>&1
check "the self-test passes end to end and says how long Claude took" "grep -q '✓ Passed: Claude answered in' $W/c1.out"
check "it creates its own task once, and a pass only updates the status line" "applied_json | grep -q '⚙︎ Server daily self-test' && applied_json | grep -q '✓ Self-test passed' && ! applied_json | grep -q 'My daily self-test'"
n_create=$(st 's.applied.filter(c=>c.op==="create_task"&&c.title==="⚙︎ Server daily self-test").length')
FAKE_CANARY_FAIL=1 canary > "$W/c2.out" 2>&1
check "a failure names the step and the fix, comments on its task, and needs attention" "grep -q '✗ Failed at Claude session: Claude usage limit reached' $W/c2.out && grep -q 'fix:' $W/c2.out && applied_json | grep -q '✗ My daily self-test failed' && [ \"\$(activity)\" = attention ]"
check "it doesn't make a second task" "[ \"\$(st 's.applied.filter(c=>c.op===\"create_task\"&&c.title===\"⚙︎ Server daily self-test\").length')\" = $n_create ]"
canary > "$W/c3.out" 2>&1
check "a recovery says so" "grep -q '✓ Passed' $W/c3.out && applied_json | grep -q 'self-test passes again'"
PATH="$W/bin:$PATH" node -r ./mock.js "$SERVER" doctor > "$W/c4.out" 2>&1
check "doctor shows the last self-test" "grep -q '✓ last self-test passed' $W/c4.out"
node -r ./mock.js "$SERVER" canary at 00:00 > /dev/null
node -e "const f=process.env.HOME+'/.workflow-companion/config.json',c=require(f);delete c.canaryLastDay;require('fs').writeFileSync(f,JSON.stringify(c))"
before_tests=$(grep -c 'self-test:' "$HOME/.workflow-companion/wake.log")
PATH="$W/bin:$PATH" wake; PATH="$W/bin:$PATH" wake
kill $MAC
check "the scheduled job runs it once a day, when nothing else is waiting" "[ \$(grep -c 'self-test:' $HOME/.workflow-companion/wake.log) = \$((before_tests + 1)) ]"

PATH="$W/bin:$PATH" WF_NO_SCHEDULE= node -r ./mock.js "$SERVER" wake-off > /dev/null 2>&1
check "wake-off removes the schedule" "! grep -q 'workflow-companion wake' $W/bin/crontab.txt"

# 1.8.1: doctor checks the chain and says how to fix it.
node mac.js & MAC=$!
node -r ./mock.js "$SERVER" doctor > "$W/d1.out" 2>&1; D1=$?
kill $MAC
check "doctor confirms the sign-in, the snapshot and a round trip" "grep -q '✓ iCloud sign-in works' $W/d1.out && grep -q '✓ .*tasks, published' $W/d1.out && grep -q '✓ a test command was applied' $W/d1.out"
check "doctor flags what's missing, with the fix" "grep -q \"✗ Claude Code doesn't have the companion\" $W/d1.out && grep -q 'fix: claude mcp add' $W/d1.out && [ $D1 = 1 ]"
node drive.js '[["workflow_doctor"]]' > "$W/d2.out"
check "doctor is a tool too, without the round trip" "grep -q '#1 ok  WorkFlow companion' $W/d2.out && ! grep -q 'test command' $W/d2.out"
node -e "const f=process.env.MOCK_STATE,s=require(f);s.expired=true;require('fs').writeFileSync(f,JSON.stringify(s))"
node -r ./mock.js "$SERVER" doctor > "$W/d3.out" 2>&1
check "an ended sign-in is named, with the command that fixes it" "grep -q '✗ the iCloud sign-in has ended' $W/d3.out && grep -q 'fix: npx -y @opticell/workflow-companion@latest setup' $W/d3.out"
node -e "const f=process.env.MOCK_STATE,s=require(f);s.expired=false;require('fs').writeFileSync(f,JSON.stringify(s))"

# 2.0: the merged tools. Old names still answer; only the 15 are listed.
listed() { printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | node -r ./mock.js "$SERVER" --cloud 2>/dev/null | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{const t=JSON.parse(d.trim().split('\n').pop()).result.tools;console.log(t.length, t.map(x=>x.name).join(' '))})"; }
check "eighteen tools are listed (2.2 adds workflow_propose, workflow_brief and workflow_download), none of the old ones" "[ \"\$(listed | cut -d' ' -f1)\" = 18 ] && ! listed | grep -qw workflow_set_status_line && listed | grep -qw workflow_list && listed | grep -qw workflow_download"
node mac.js & MAC=$!
n0=$(st 's.applied.length')
node drive.js '[["workflow_list",{"query":"backup"}],["workflow_list",{"kind":"notes"}],["workflow_get",{"id":"quarterly"}],["workflow_get",{"id":"N1"}],["workflow_get",{"id":"nothing like it"}],
  ["workflow_update_task",{"task":"T1","status_line":"half way","check_subtasks":["draft"],"rename_subtasks":[{"from":"draft","to":"first draft"}]}],
  ["workflow_comment",{"task":"T2","text":"over to you","hand_to":"Claude"}],["workflow_comment",{"task":"T2"}],
  ["workflow_note",{"action":"reply","note":"Ideas","text":"noted"}],["workflow_note",{"action":"tidy"}],
  ["workflow_attach",{"file":"'"$W"'/report.pdf","task":"T1","project":"Ops"}],["workflow_attach",{"file":"'"$W"'/report.pdf","task":"T1"}],
  ["workflow_approval",{"action":"check"}],["workflow_state",{"check":"ping"}],["workflow_set_status_line",{"task":"T1","text":"old name"}]]' > "$W/m1.out"
kill $MAC
new_ops() { node -e "const s=require(process.env.MOCK_STATE);console.log(JSON.stringify(s.applied.slice($n0)))"; }
check "list searches tasks" "grep -A1 '^#1 ok' $W/m1.out | grep -q 'Rotate the backups' && ! sed -n '/^#1/,/^#2/p' $W/m1.out | grep -q 'Quarterly'"
check "list kind notes is the Notepad" "sed -n '/^#2/,/^#3/p' $W/m1.out | grep -q 'Ideas'"
check "get finds a task by title and a note by id" "sed -n '/^#3/,/^#4/p' $W/m1.out | grep -q 'comment(s):' && sed -n '/^#4/,/^#5/p' $W/m1.out | grep -q 'id N1'"
check "get says when nothing matches" "grep -q '#5 ERR Nothing matches' $W/m1.out"
check "status line, ticks and a rename go as one command" "new_ops | node -e \"const a=JSON.parse(require('fs').readFileSync(0));const u=a.filter(c=>c.op==='update_task'&&c.pinnedNote==='half way');process.exit(u.length===1&&u[0].checkSubtasks[0]==='draft'&&u[0].renameSubtasks[0].to==='first draft'?0:1)\""
check "hand_to reassigns and @mentions the assistant" "new_ops | grep -q '\"assignee\":\"Claude\"' && new_ops | grep -q '@Claude handing this over to you. over to you'"
check "a comment without text is refused" "grep -q '#8 ERR Give text.' $W/m1.out"
check "note reply appends to the note" "new_ops | grep -q '\"op\":\"update_note\".*\"appendText\":\"noted\"'"
check "a bad action is named" "grep -q '#10 ERR action is create, reply or convert.' $W/m1.out"
check "attach wants exactly one target, and attaches to a task" "grep -q '#11 ERR Give exactly one of task, project or document.' $W/m1.out && grep -q '#12 ok  \[ok\] did attach_file' $W/m1.out"
check "approval check needs a code" "grep -q '#13 ERR Give code.' $W/m1.out"
check "state check ping round-trips" "grep -q '#14 ok  \[ok\] did ping' $W/m1.out"
check "an old tool name still works" "grep -q '#15 ok  \[ok\] did update_task' $W/m1.out && new_ops | grep -q '\"pinnedNote\":\"old name\"'"

# 2.2 / WorkFlow 5.6.1: a file comes back from WorkFlow through iCloud.
node mac.js & MAC=$!
mkdir -p "$W/dl"
node drive.js '[["workflow_download",{"document":"WF-D1A2B3","save_to":"'"$W"'/dl"}],["workflow_download",{"document":"readings.csv","save_to":"'"$W"'/dl"}],["workflow_download",{"document":"broken.bin","save_to":"'"$W"'/dl"}]]' > "$W/dl.out"
kill $MAC
check "a download arrives, checked, under its own name" "grep -q '#1 ok  Saved WF-D1A2B3 “readings.csv” (26 bytes, SHA-256 checked)' $W/dl.out && [ \"\$(cat $W/dl/readings.csv)\" = \"\$(printf 'date,temp\n2026-10-27,14.5')\" ]"
check "a second download never overwrites the first" "[ -f '$W/dl/readings (2).csv' ]"
check "a damaged download is refused and not saved" "grep -q '#3 ERR The file arrived damaged' $W/dl.out && [ ! -f $W/dl/broken.bin ]"
check "downloads are deleted from iCloud once collected" "[ \"\$(st 'Object.keys(s.records).filter(k=>k.startsWith(\"download-\")).length')\" = 0 ]"

exit $fail
