#!/bin/sh
# WorkFlow companion: install on a Mac or Linux in one line:
#   curl -fsSL https://raw.githubusercontent.com/TeamDzX/workflow-companion/main/install.sh | sh
# Installs Node.js if needed (Homebrew on a Mac), signs this computer in to
# iCloud for WorkFlow, adds the companion to Claude Code, and offers to let it
# start work on its own.
set -u
# Run through a pipe, stdin is this script: questions are read from the terminal.
TTY=/dev/tty
printf '\nWorkFlow companion setup\n\n'

node_major() { node -v 2>/dev/null | sed -n 's/^v\([0-9][0-9]*\).*/\1/p'; }
m=$(node_major)
if [ -z "$m" ] || [ "$m" -lt 18 ]; then
  if [ "$(uname)" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
    echo "Installing Node.js with Homebrew..."
    brew install node || { echo "Homebrew couldn't install Node.js. Install the LTS from https://nodejs.org and run this again."; exit 1; }
  else
    echo "Node.js 18 or later is needed. Install the LTS from https://nodejs.org (or your package manager), then run this again."
    exit 1
  fi
fi
echo "Node.js $(node -v) OK"
echo

echo "Step 1 of 3: sign in to iCloud for WorkFlow (a browser window opens)"
npx -y @opticell/workflow-companion@latest setup < "$TTY" || { echo "Sign-in didn't finish. Run the same command again to retry."; exit 1; }

if command -v claude >/dev/null 2>&1; then
  echo; echo "Step 2 of 3: add it to Claude Code"
  claude mcp remove workflow -s user >/dev/null 2>&1
  claude mcp add --scope user workflow -- npx -y @opticell/workflow-companion@latest
  echo; printf 'Step 3 of 3: start work on its own when you hand it something in WorkFlow? (Y/n) '
  read -r answer < "$TTY" || answer=y
  case "$answer" in [nN]*) ;; *) npx -y @opticell/workflow-companion@latest wake-on ;; esac
else
  echo; echo "Claude Code isn't installed yet. Install it from https://claude.com/claude-code and sign in, then run:"
  echo "  claude mcp add --scope user workflow -- npx -y @opticell/workflow-companion@latest"
  echo "  npx -y @opticell/workflow-companion@latest wake-on"
fi
echo; echo "Done. Check on it any time with: npx -y @opticell/workflow-companion@latest status"
