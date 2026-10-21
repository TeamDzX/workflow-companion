#!/usr/bin/env python3
"""Builds the release from src/index.js, into dist/:
  dist/package/      the npm package (index.js, package.json, README.md, LICENSE)
  dist/WorkFlow.mcpb the Claude Desktop bundle
The version comes from SERVER_INFO in src/index.js. The CloudKit API token
isn't in the source: WF_CK_API_TOKEN supplies it (a GitHub secret in CI).
"""
import json, os, re, shutil, sys, zipfile

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.dirname(here)
out = os.path.join(root, "dist")
code = open(os.path.join(root, "src", "index.js")).read()
m = re.search(r'^const SERVER_INFO = \{ name: "workflow", version: "([0-9.]+)" \};$', code, re.M)
if not m:
    sys.exit("couldn't read the version from src/index.js")
version = m.group(1)
token = os.environ.get("WF_CK_API_TOKEN", "")
marker = '  apiToken: "",'
if code.count(marker) != 1:
    sys.exit("apiToken line not found in src/index.js")
if not token:
    sys.exit("WF_CK_API_TOKEN isn't set: the package would need --api-token at setup")
code = code.replace(marker, f"  apiToken: {json.dumps(token)},")

shutil.rmtree(out, ignore_errors=True)
os.makedirs(os.path.join(out, "package"))
with open(os.path.join(out, "package", "index.js"), "w") as f:
    f.write(code)
os.chmod(os.path.join(out, "package", "index.js"), 0o755)
pkg = json.load(open(os.path.join(root, "package.json")))
pkg["version"] = version
json.dump(pkg, open(os.path.join(out, "package", "package.json"), "w"), indent=2)
for name in ("README.md", "LICENSE"):
    shutil.copy(os.path.join(root, name), os.path.join(out, "package", name))

manifest = {
    "manifest_version": "0.2", "dxt_version": "0.1",
    "name": "workflow-companion", "display_name": "WorkFlow Companion", "version": version,
    "description": "Work in your WorkFlow tasks, notes and projects from Claude on Windows or Linux, through WorkFlow for Mac and your own iCloud.",
    "long_description": "WorkFlow for Mac 5.2+ applies every change, with Settings → Agent Bridge → Cloud Bridge on. Sign in at https://companion.opticell-limited.com and paste the token into this extension's Sign-in token setting.",
    "author": {"name": "Opticell Limited", "url": "https://www.opticell-limited.com/companion"},
    "homepage": "https://www.opticell-limited.com/companion",
    "server": {"type": "node", "entry_point": "server/index.js",
               "mcp_config": {"command": "node", "args": ["${__dirname}/server/index.js", "--cloud"],
                              "env": {"WF_SIGNIN_TOKEN": "${user_config.sign_in_token}", "WF_AGENT_NAME": "${user_config.agent_name}"}}},
    "user_config": {
        "sign_in_token": {
            "type": "string", "title": "Sign-in token", "sensitive": True, "required": False,
            "description": "From https://companion.opticell-limited.com: sign in with the Apple Account WorkFlow uses on your Mac and paste the token it shows. Paste a fresh one here if the companion ever says to sign in again."},
        "agent_name": {
            "type": "string", "title": "Name in WorkFlow", "required": False, "default": "Companion",
            "description": "What Claude on this computer is called in WorkFlow. Assign a task to this name, or write @name in a comment or note, to hand it work. One word, not \"Claude\"."}},
    "tools": [{"name": n, "description": d} for n, d in [
        ("workflow_queue", "Your inbox"), ("workflow_list", "Tasks, notes, projects, documents"),
        ("workflow_get", "One task with its thread"), ("workflow_comment", "Reply on a task"),
        ("workflow_update_task", "Status line, checklist, fields"), ("workflow_state", "Is the bridge working")]],
    "compatibility": {"platforms": ["win32", "linux", "darwin"], "runtimes": {"node": ">=18.0.0"}},
    "keywords": ["tasks", "projects", "workflow", "icloud"],
}
with zipfile.ZipFile(os.path.join(out, "WorkFlow.mcpb"), "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("manifest.json", json.dumps(manifest, indent=2, ensure_ascii=False))
    z.writestr("server/index.js", code)
print(version)
