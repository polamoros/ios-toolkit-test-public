# Security and robustness audit, September 2026

One round of finders plus an independent review, on 2026-09-27, before the
first publication to the public mirror. Five finders reported one finding;
all three skeptics confirmed it (Low), and it is fixed with a test proven by
reverting. Nothing is left open.

Audited: `polamoros/ios-toolkit-test` at `f7d6cf99bd39224f38aa35442bc9b9d5ab6b901b`
(the ios-app 0.3.1 scaffold), plus the fix commit `0a64183` on top of it. The
commit published is the one that adds this report (parent `0a64183`); it
changes nothing but this file. Out of scope: DockAI's own files (`.dockai/`,
`CLAUDE.local.md`, both untracked), the DockAI server and its release gate,
GitHub and App Store Connect account settings (whether the `testflight`
environment exists with the owner as required reviewer, and the role of the
App Store Connect key) — those live outside the repository.

## Where the fixes are

| Branch | Base | Holds |
|---|---|---|
| `main` | `f7d6cf9` | `0a64183` (F1) |

## Method

- Finders by dimension, from the security-audit checklist: authentication and
  authorization; input and injection; secrets; isolation and blast radius;
  robustness and failure together with data.
- Three skeptics per finding; confirmed only when all three failed to refute.
- Each fix has a test that failed with the fix reverted and passed with it
  restored; the commit message records it.
- Checks per round: `bash ci/check-tree.sh`, `bash -n generate.sh`,
  `node --check ci/mock-server.mjs`, `python3 -m py_compile ci/asc_jwt.py`
  (in a copy outside the repository). The worker has no Swift toolchain and
  no Mac: Swift and the Xcode project are checked only by the public mirror's
  compile job.

| Round | Reported | Confirmed | Refuted | Fixed in round | Fixed later |
|---|---|---|---|---|---|
| 1 | 1 | 1 | 0 | 1 | 0 |
| Independent review | 0 | 0 | 0 | 0 | 0 |

The round stops here: it produced no high and no medium finding.

Skeptic note: 0 refuted of 1. The finding is a fact checkable with one
command (`git ls-tree`), so all three skeptics agreeing is expected rather
than a sign they did not try; each also checked the file's content for
leaked paths and names (none) and one recompiled the source to confirm it is
identical bytecode. One skeptic also cited `ci/check-tree.sh`, which was
then an uncommitted draft of the fix; its confirmation rests on
`git ls-tree` and `.gitignore` independently of that.

## Round 1

| # | Sev | File | What was wrong | Fix | Commit |
|---|---|---|---|---|---|
| F1 | Low | `ci/__pycache__/asc_jwt.cpython-312.pyc` | Python bytecode, produced by a local syntax check during scaffolding, was committed and nothing ignored it, so it would have been published to the public mirror. It carried no secret or local path (only the relative `ci/asc_jwt.py`). | Removed from the tree; `__pycache__/` and `*.pyc` ignored; `ci/check-tree.sh` fails the compile job when generated or local files (bytecode, `.xcodeproj`, `.xcresult`, `build/`, logs, `.DS_Store`, signing files) are tracked. Test: with the `.pyc` tracked again the check exits 1 and names it; with the fix restored it exits 0. | `0a64183` |

Checked and not findings (each finder traced these end to end):

- Only `compile` runs on `pull_request`; it holds no secret, has
  `contents: read` and `persist-credentials: false`. `simulator` and
  `testflight` run only on `workflow_dispatch`; `testflight` also waits for
  the `testflight` environment's reviewer.
- No attacker-controlled `${{ }}` context is interpolated into a `run:`
  script (only `github.run_number`); secrets reach scripts through `env:`.
- Third-party actions are pinned by commit SHA; XcodeGen is pinned and
  checked against its SHA-256; nothing unpinned is installed in the job that
  holds the App Store Connect key.
- The `DOCKAI_TEST_SERVER` hook is inside `#if DEBUG`, and the upload step
  refuses a Release archive containing the name.
- A failed build cannot pass: every `|| true` is followed by a `grep -q` on
  the success line.
- The mock server binds to `127.0.0.1` and serves invented data only.

## Independent review

| # | Sev | File | What was wrong | Fix | Commit |
|---|---|---|---|---|---|
| — | — | — | No discrepancies: every change F1 claims is in `0a64183` on `main`; `git ls-files` holds only source (12 files); the new step runs after checkout with only git and bash; the check's patterns match `.gitignore`; it exits 0 on the clean tree under `set -euo pipefail`; the commit changes only the four files it names. | — | — |

(Cosmetic: the F1 commit message quotes "11 files"; with `check-tree.sh`
itself the tree holds 12.)

## Behaviour that changes

The compile job now starts with "Only source is tracked" and fails, naming
the files, when a generated or local file is committed.

## Accepted, and open

Nothing open. Notes that are not defects today:

- `NSAllowsLocalNetworking` is also in the Release build; Release only
  requests `https://example.com`, so it permits nothing in use.
- If the `testflight` job fails before `rm -f "$KEY"`, the key file stays in
  `$RUNNER_TEMP`; GitHub-hosted runners are discarded after each job. On a
  self-hosted runner add `trap 'rm -f "$KEY"' EXIT`.
- `ScreensUITests.assertPullRefreshes` returns without failing when the mock
  server is unreachable; `testMain` fails earlier in that case, but a future
  screen that renders without the server would skip the check silently.

## Before going public

Run on the tree of the commit that adds this report (the scaffold plus
`0a64183` plus this file) and on the full history.

| Check | Tool | Result |
|---|---|---|
| Secrets, tree and history | gitleaks 8.30.1 (release checksum verified): `gitleaks git` over all commits and `gitleaks dir` over the tree | No leaks |
| Private names | `git grep` over every commit for the owner's email domain, personal email patterns, private hostnames and IP ranges, and internal domains | Only the owner's public GitHub handle, which is part of the bundle id and of the public mirror's own name, and the name of the DockAI toolkit that generated the scaffold |
| Test output and fixtures | `git ls-files` for images, recordings, logs, result bundles, key, certificate and profile files | None; the only fixture is the mock server's three invented strings |
| Licences | Review of every dependency | No third-party code is vendored or linked. CI uses `actions/checkout` and `actions/upload-artifact` (MIT) and downloads XcodeGen (MIT) at build time; nothing of theirs is redistributed |
| What the public copy contains | The release gate | A single snapshot commit of this tree, not the private history |
