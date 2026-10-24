# This fork

`sjelfull/cleanyourtv-WebOS` is a fork of [lasharor/cleanyourtv-WebOS](https://github.com/lasharor/cleanyourtv-WebOS).
The TV takes updates from this fork only. Upstream changes reach the TV only after we review, merge and release them.

## What is different from upstream

- **The update origin is pinned** in `helper/origin.js`. The service ignores `/media/developer/cleanyourtv/source` and
  `config.json` `releasesUrl`, because any app on a rooted TV can write those files.
- **No test builds.** Upstream publishes a pre-release for every branch push. That workflow is deleted here.
- **No Actions write releases.** Releases are built and published from a trusted machine with `tools/release.sh`.
  The only workflow, `upstream-watch.yml`, reads code and writes issues.
- **Docs are not published** from this fork. Use the upstream docs site.

## Install on a TV

Do not pipe `install.sh` into `sh`. Copy it from a release tag that you have read:

```sh
TAG=v1.5.16-sjelfull.1   # the release you want
curl -fsSLo /tmp/install.sh "https://raw.githubusercontent.com/sjelfull/cleanyourtv-WebOS/$TAG/install.sh"
less /tmp/install.sh
scp /tmp/install.sh root@<tv-ip>:/tmp/install.sh
ssh root@<tv-ip> 'sh /tmp/install.sh'
```

The installer downloads the latest release of this fork and checks its SHA-256.
If the TV already runs upstream CleanYourTV, the install also moves it to this fork. After that, on the TV:

```sh
rm -f /media/developer/cleanyourtv/source            # ignored now; remove it so nothing reads it by mistake
find /media/developer/cleanyourtv ! -user root -o -perm -002   # must print nothing
```

In the manager app, the update source must show `sjelfull/cleanyourtv-WebOS`.

## Updates

1. **Upstream changes.** Every day the `Upstream watch` workflow updates one issue (label `upstream`) that lists the new
   upstream commits. It flags the files that touch install, the update path, root code or binaries.
2. **Merge.** Run `sh tools/sync-upstream.sh`. It merges upstream into a new branch, drops every upstream workflow
   change and opens a pull request. It runs no code from the merge. Resolve conflicts by keeping `helper/origin.js` pinned.
3. **Review.** Read the listed files in the pull request. Then merge it.
4. **Release.** On an up-to-date `main`, run `sh tools/release.sh`. It refuses code that could choose another update
   origin, runs the Node 8 checks, builds from a clean checkout and publishes the latest release.
5. **TV.** The manager app on the TV checks for a release about every 5 minutes and shows the update.
   Nothing installs until someone chooses Update on the TV.

`compat.json` and `themes/` are read from `main`, not from a release, so they reach the TV as soon as a pull request
is merged. Both are data, not code.

GitHub turns off scheduled workflows after 60 days without activity in the repository, and sends an email first.
If that happens, turn `Upstream watch` on again under Actions. As a backup, watch upstream on GitHub (Custom → Releases).

The TV offers a release only if its version is higher than the installed version. A change that is only in this fork
needs a higher `VERSION` in `helper/helper.js` (or a higher launcher version in `app/version.json` and `app/index.html`).

## GitHub settings for this repository

- Actions: only the workflows in this repository can run, and no actions from the marketplace. The default token is read-only.
- Rulesets: `main` takes changes only through pull requests and cannot be deleted or force-pushed. Only a repository
  admin can create release tags `v*`, and nobody can delete or move them. Workflows cannot bypass either rule.
- Releases are immutable: after a release is published, its files cannot be replaced.
- Secret scanning and push protection are on.
