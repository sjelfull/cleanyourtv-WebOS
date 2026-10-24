#!/bin/sh
# Fork: builds the package on this machine from the committed main and publishes it as the fork's latest release. TVs offer it
# in the manager app within about 5 minutes; nothing installs until someone chooses Update on the TV.
#   sh tools/release.sh          (on main, up to date with origin/main)
set -eu
FORK=sjelfull/cleanyourtv-WebOS
cd "$(dirname "$0")/.."
say() { echo "[release] $*"; }
die() { echo "[release] ERROR: $*" >&2; exit 1; }

[ "$(git branch --show-current)" = main ] || die "switch to main first"
[ -z "$(git status --porcelain)" ] || die "the working tree is not clean"
git fetch -q origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "main is not the same as origin/main (pull or push first)"

# the update origin must be pinned in helper/origin.js and nowhere else
grep -q "'sjelfull/cleanyourtv-WebOS'" helper/origin.js || die "helper/origin.js does not pin this fork"
leak=$(git grep -nE "'/source'|/source'|\\\$D/source|\.releasesUrl|'lasharor/cleanyourtv-WebOS'|api\.github\.com/repos/' \+ \(" -- helper scripts install.sh app manager picker notify ':!helper/origin.js' || true)
[ -z "$leak" ] || { echo "$leak"; die "code outside helper/origin.js may choose where updates come from"; }

# build from a clean checkout of HEAD, so files that git ignores never end up in the package
W=$(mktemp -d); trap 'git worktree remove --force "$W" >/dev/null 2>&1 || true; rm -rf "$W"' EXIT
git worktree add -q --detach "$W" HEAD
say "running the checks under Node 8"
(cd "$W" && sh tools/node8-check.sh) >/tmp/cytv-release-check.log 2>&1 || { tail -20 /tmp/cytv-release-check.log; die "checks failed (log: /tmp/cytv-release-check.log)"; }
(cd "$W" && python3 ipk/build.py)
svc=$(sed -n "s/^const VERSION = '\(.*\)';/\1/p" "$W/helper/helper.js" | head -1)
fe=$(node -p 'require(process.argv[1]).version' "$W/app/version.json")

# the TV only offers a higher version than it has: one of the two numbers must go up, or the release reaches nobody
if last=$(gh release view -R "$FORK" --json assets -q '[.assets[].name] | join("\n")' 2>/tmp/cytv-release-gh.err); then
  lsvc=$(echo "$last" | sed -n 's/^com\.cleanyourtv\.manager_\(.*\)_all\.ipk$/\1/p'); lfe=$(echo "$last" | sed -n 's/^frontend-\(.*\)\.tgz$/\1/p')
  higher() { node -e 'const p=v=>String(v||"0").split(".").map(Number),a=p(process.argv[1]),b=p(process.argv[2]);for(let i=0;i<3;i++)if((a[i]||0)!==(b[i]||0))process.exit((a[i]||0)>(b[i]||0)?0:1);process.exit(1)' "$1" "$2"; }
  higher "$svc" "$lsvc" || higher "$fe" "$lfe" || die "service $svc / launcher $fe is not newer than the last release ($lsvc / $lfe); raise VERSION in helper/helper.js or the launcher version"
elif grep -qi "not found" /tmp/cytv-release-gh.err; then
  say "first release of the fork"
else
  cat /tmp/cytv-release-gh.err; die "could not read the last release"
fi

i=1; while git ls-remote --exit-code --tags origin "refs/tags/v$svc-sjelfull.$i" >/dev/null 2>&1; do i=$((i+1)); done
tag="v$svc-sjelfull.$i"
notes=$(mktemp)
{
  echo "Service $svc, launcher $fe. Built locally from $(git rev-parse --short HEAD)."
  if git remote get-url upstream >/dev/null 2>&1 && git fetch -q --no-tags upstream main; then echo "Upstream base: lasharor/cleanyourtv-WebOS@$(git merge-base HEAD upstream/main | cut -c1-7)"; fi
  echo; echo "SHA-256:"; echo '```'; cat "$W"/dist/*.sha256; echo '```'
} > "$notes"
say "publishing $tag"
git tag -a "$tag" -m "$tag"
git push -q origin "$tag"
gh release create "$tag" -R "$FORK" --verify-tag --latest --title "$tag" --notes-file "$notes" "$W"/dist/*
rm -f "$notes"
say "done. The TVs offer service $svc / launcher $fe in the CleanYourTV manager app."
