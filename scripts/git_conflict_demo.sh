#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Git conflict demonstration.
#
# Creates a throw-away clone in a temp directory, makes two branches that edit
# the SAME line of app/config.py, merges them, shows the conflict markers,
# resolves the conflict, commits and prints the branch graph.
#
# It NEVER touches the real repository. Safe to run any number of times.
#
# Usage: bash scripts/git_conflict_demo.sh
# ---------------------------------------------------------------------------
set -uo pipefail

export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/true

REPO_URL="${REPO_URL:-https://github.com/atharvadhanwate11/devops-demo-app.git}"
LOCAL_REPO="${LOCAL_REPO:-$HOME/devops-demo-app}"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
cyan()  { printf '\033[0;36m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[0;33m%s\033[0m\n' "$*"; }

WORKDIR="$(mktemp -d -t conflict-demo-XXXXXX)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

bold "=============================================================="
bold " GIT CONFLICT DEMO   (throw-away clone in $WORKDIR)"
bold "=============================================================="

echo
bold "[1/7] Clone the repository into a temporary directory"
if git clone --quiet "$REPO_URL" "$WORKDIR/repo" 2>/dev/null; then
  echo "  cloned from $REPO_URL"
else
  echo "  remote clone failed, falling back to the local repository"
  git clone --quiet "$LOCAL_REPO" "$WORKDIR/repo"
fi
cd "$WORKDIR/repo"
git config user.name  "Conflict Demo"
git config user.email "conflict-demo@example.com"
git checkout --quiet -b demo/base 2>/dev/null || git checkout --quiet demo/base
git log --oneline -n 1 | sed 's/^/  base commit: /'

echo
bold "[2/7] Branch A changes MAX_TITLE_LENGTH to 120"
git checkout --quiet -b feature/config-a demo/base
sed -i 's/^MAX_TITLE_LENGTH = .*/MAX_TITLE_LENGTH = 120/' app/config.py
grep -n "MAX_TITLE_LENGTH =" app/config.py | sed 's/^/  /'
git commit --quiet -am "feat(config): set MAX_TITLE_LENGTH to 120"

echo
bold "[3/7] Branch B changes the same line to 80"
git checkout --quiet -b feature/config-b demo/base
sed -i 's/^MAX_TITLE_LENGTH = .*/MAX_TITLE_LENGTH = 80/' app/config.py
grep -n "MAX_TITLE_LENGTH =" app/config.py | sed 's/^/  /'
git commit --quiet -am "feat(config): set MAX_TITLE_LENGTH to 80"

echo
bold "[4/7] Merge branch A into branch B -> conflict!"
git merge feature/config-a 2>&1 | sed 's/^/  /' || true

echo
bold "[5/7] The conflict markers inside app/config.py"
grep -n -E "^(<<<<<<<|=======|>>>>>>>)" app/config.py | sed 's/^/  /'
echo "  ---- the conflicted file ----"
sed -n '/<<<<<<</,/>>>>>>>/p' app/config.py | sed 's/^/  /'

echo
bold "[6/7] Resolve the conflict (keep the higher limit: 120) and commit"
python3 - <<'PY'
import pathlib, re
p = pathlib.Path("app/config.py")
s = p.read_text()
s = re.sub(r"<<<<<<< [^\n]*\n.*?\n=======\n.*?\n>>>>>>> [^\n]*\n",
           "MAX_TITLE_LENGTH = 120\n", s, flags=re.S)
p.write_text(s)
PY
grep -n "MAX_TITLE_LENGTH =" app/config.py | sed 's/^/  /'
git add app/config.py
git commit --quiet -m "fix(config): resolve MAX_TITLE_LENGTH conflict, keeping 120"

echo
bold "[7/7] Resulting branch graph"
git log --oneline --graph --all --decorate | sed 's/^/  /'

echo
green "CONFLICT DEMO COMPLETE - the real repository was never modified."
bold "=============================================================="
