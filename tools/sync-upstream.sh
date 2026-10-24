#!/bin/sh
# Fork: merges upstream main into a new branch and opens a pull request in the fork for review. It runs NO code from the
# merge: the checks run in tools/release.sh, after the pull request is read and merged. Nothing reaches a TV before that.
#   sh tools/sync-upstream.sh
set -eu
UPSTREAM=https://github.com/lasharor/cleanyourtv-WebOS.git
FORK=sjelfull/cleanyourtv-WebOS
cd "$(dirname "$0")/.."
say() { echo "[sync] $*"; }
die() { echo "[sync] ERROR: $*" >&2; exit 1; }

[ -z "$(git status --porcelain)" ] || die "the working tree is not clean"
if git remote get-url upstream >/dev/null 2>&1; then
  [ "$(git remote get-url upstream)" = "$UPSTREAM" ] || die "the remote upstream is not $UPSTREAM"
else
  git remote add upstream "$UPSTREAM"
fi
git fetch -q origin main
git fetch -q --no-tags upstream main
n=$(git rev-list --count origin/main..upstream/main)
[ "$n" -gt 0 ] || { say "already up to date with upstream"; exit 0; }

B=sync/upstream-$(date +%Y%m%d-%H%M%S)
git switch -q -c "$B" origin/main
say "merging $n upstream commit(s) into $B"
merged=1
git merge -q --no-ff --no-commit upstream/main || merged=0
git rev-parse -q --verify MERGE_HEAD >/dev/null || die "the merge did not start; see the git output above"

# The fork runs only its own workflow. A pushed branch runs the workflows it contains, so every upstream workflow change
# is dropped before anything is pushed, conflict or not.
for f in $(git diff --cached --name-only --no-renames origin/main -- .github/workflows) $(git diff --name-only --diff-filter=U -- .github/workflows); do
  [ "$f" = .github/workflows/upstream-watch.yml ] && git checkout -q origin/main -- "$f" && continue
  git rm -q -f --ignore-unmatch "$f"; say "dropped upstream workflow $f"
done
[ -z "$(git diff --cached --name-only origin/main -- .github/workflows)" ] || die "workflow changes are still staged; nothing was pushed"

if [ -n "$(git diff --name-only --diff-filter=U)" ]; then
  say "conflicts to resolve by hand (keep helper/origin.js pinned):"; git diff --name-only --diff-filter=U
  say "then: git commit --no-edit, check 'git diff origin/main -- .github/workflows' is empty, git push -u origin $B, gh pr create -R $FORK --fill"
  exit 1
fi
git commit -q --no-edit

# the update origin must stay pinned: warn about new code that reads D/source or releasesUrl, or names upstream's repository
warn=$(git diff origin/main HEAD -- helper scripts install.sh app manager picker notify | grep -E "^\+.*(/source|releasesUrl|lasharor/cleanyourtv-WebOS|api\.github\.com|githubusercontent)" | grep -v '^+++' || true)

base=$(git merge-base origin/main upstream/main)
# everything outside the docs runs as root on the TV, runs on this Mac (tools/), or is data the TV loads
review=$(git diff --name-only --no-renames "$base" upstream/main | grep -vE '^(docs/|site/|assets/|zensical\.toml$|[^/]+\.md$|\.github/ISSUE_TEMPLATE/)' || true)
body=$(mktemp)
{
  echo "Merges $n upstream commit(s). Compare: https://github.com/lasharor/cleanyourtv-WebOS/compare/${base}...main"
  echo
  echo "No code from this merge has run yet. \`tools/release.sh\` runs the checks after you merge."
  if [ -n "$warn" ]; then echo; echo "### The update origin may be unpinned again"; echo '```'; echo "$warn"; echo '```'; fi
  if [ -n "$review" ]; then echo; echo "### Code and data that reach the TV or this Mac (read these)"; echo '```'; echo "$review"; echo '```'; fi
  echo; echo "### Commits ($n)"; echo '```'; git log --format='%h %s (%an, %as)' origin/main..upstream/main | head -100; [ "$n" -le 100 ] || echo "... and $((n - 100)) more"; echo '```'
  echo; echo "After merging: \`sh tools/release.sh\` on main."
} > "$body"
git push -q -u origin "$B"
gh pr create -R "$FORK" --base main --head "$B" --title "Merge upstream $(git rev-parse --short upstream/main)" --body-file "$body"
rm -f "$body"
[ -z "$warn" ] || say "WARNING: new code may change where updates come from; see the pull request"
