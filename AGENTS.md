# Agent guidance

Generic low-latency tuning guides for RHEL 8, 9 and 10 bare metal and VMs. Each guide in `guides/NN-*.md` has one script `scripts/NN-*` that applies, verifies and rolls it back. `concepts/` explains the mechanisms, and `examples/` holds worked examples, including a runnable Java probe (`examples/java-latency-probe/`, which has its own `CLAUDE.md`).

These rules apply to every change, whoever makes it. If a rule and a request conflict, say so before acting.

## 1. Keep it generic

- Never name the private project the tuning came from, an employer, a customer, internal paths, service accounts, or proprietary middleware and its vocabulary.
- Use the neutral names already in the repo: NIC roles (`critical`, `timing`, `bulk`, `mgmt`), `/opt/lowlat`, `app-user`, and thread roles such as `net.rx`, `event.loop` and `worker.N`.
- No real host names, IP addresses, serial numbers, logs or secrets in docs or examples. Sanitize anything pasted from a real machine.
- Before finishing, grep the diff for leaks.

## 2. How to work

- **Clarify first.** Restate the goal, including what is out of scope. If the request is underspecified, ask 1–5 targeted questions instead of inventing a spec. If the source material looks odd, list the oddities and let the owner decide.
- **Unix creed.** Clarity over cleverness. Do the simplest thing that works. Say nothing when there is nothing to say. Fail loudly and early. Measure before optimizing.
- **Delete dead code** in the same change that makes it dead. No "kept for later" comments.
- **Minimal, coherent diffs.** Do not refactor what the task does not need.
- **Verify before handing off.** Run `make lint` and report the real result, not "should pass".

## 3. Documentation

- Guides are deep. For every setting they explain what it does, why this value was chosen, how to verify it, how to troubleshoot it and how to roll it back. Never ship an outline.
- One script per guide. A new guide `guides/NN-name.md` comes with `scripts/NN-name`, and with entries in `README.md`, `INDEX.md` and `QUICK_START.md`, all in the same change.
- Advice that follows documentation and that this repository does not measure is marked **Validate on your hardware** in the text.
- Pages follow [`STYLE.md`](STYLE.md): the short answer first (At a glance), a diagram where a flow, layout or decision needs one, an animation where time is the point, one "Picture it" line per abstract mechanism, depth folded into `<details>`, and Key takeaways at the end.
- American English in every committed file.
- New jargon goes into [`GLOSSARY.md`](GLOSSARY.md) in the same change: plain English, short sentences, an entry id that keeps the A–Z order (`tools/check-glossary` enforces it, and `tools/check-glossary --missing` lists acronyms with no entry).
- Use cases (`examples/use-cases/`) follow the same skeleton (situation, diagnose, change, result, verify and roll back, takeaways), are listed in `examples/use-cases/README.md`, `README.md` and `INDEX.md`, and reuse commands that a guide already documents. Every number that is not a measurement is labeled illustrative.
- `site/` is hand-written HTML, CSS and JavaScript with no dependencies and no external loads. `site/layout.js` is a port of `scripts/plan-layout`: change the rules in both, and update the golden files (`tools/check-plan-layout --update`). `site/buffers.js` is a port of `scripts/size-buffers` in the same way (`tools/check-size-buffers --update`).
- A new guide also goes into the guide grid of `site/index.html`, `scripts/apply-all`, `scripts/verify-tuning` and the guide counts in `README.md`.

## 4. Tuning stance

- Huge pages for latency JVMs: explicit hugetlbfs, reserved per NUMA node at early boot. Never transparent huge pages (`transparent_hugepage=never`).
- IRQs and softirqs of kernel-stack NICs never run on isolated CPUs.
- Every runtime (non-persistent) setting is re-applied at boot by `lowlat-runtime.service`.

## 5. Shell scripts

- **No file extension.** Name the file after its purpose (`04-network`, `verify-tuning`), start it with `#!/usr/bin/env bash`, `set -Eeuo pipefail`, and `chmod +x`. Sourced files (`scripts/lib/*`, `lowlat.conf*`) are not executable.
- Prefix every host path (`/sys`, `/proc`, `/etc`, `/boot`, `/usr/lib/systemd`, `/var/lib`) with `${LOWLAT_ROOT}`. It is empty on a real host, and `tools/check-scripts` points it at a fake host. The commands a script runs must have a fake in `tools/stubs`. When behavior changes, review the diff of `scripts/fixtures/hosts/*/expected` and commit it with the change.
- Reuse `scripts/lib/common`: logging, dry-run aware `run`/`write_file`, `read_value`, CPU-list helpers and verify helpers.
- **ShellCheck `enable=all` is clean** (root `.shellcheckrc`). A per-line `# shellcheck disable=SCxxxx` needs a one-line reason above it.
- Functions called in a condition are predicates. They return a status and never rely on errexit inside them.
- Do not hide a failing command inside `"$(...)"`. Assign it to a variable first, or add `|| true` on purpose.
- No project or product prefix in function names, variables or log lines. Checkers are named `check-*`, never `test-*`.
- Tabs for indentation (`.editorconfig`).

## 6. Java (`examples/java-latency-probe`)

- **Build with Gradle only** (Kotlin DSL, wrapper). Never add Maven files.
- **No new library without the owner's explicit approval.** Once approved, add it to `approvedDependencies` in `build.gradle.kts` and regenerate `gradle/verification-metadata.xml` (`./gradlew --write-verification-metadata sha256 check`).
- **Native calls use FFM** (`java.lang.foreign`), never third-party affinity or JNI wrappers.
- **Checkstyle is clean** (`config/checkstyle/checkstyle.xml`): `final` parameters and locals, braces everywhere, no star or unused imports, no `Thread.sleep`.
- **Early exit, no `else`.** Handle the special case and `return`/`continue`, and do not nest an `if` inside an `if`.
- **Toolchain:** Java 25 via SDKMAN (`sdk env` reads `.sdkmanrc`).

## 7. Quality gate

| Command | What it checks |
|---|---|
| `make lint` | everything below. CI runs it (`.github/workflows/lint.yml`) |
| `make lint-scripts` | no `.sh`/`.bash` files, exec bits, ShellCheck `enable=all`, `bash -n`, `tools/check-plan-layout` (`plan-layout` against the fixtures in `scripts/fixtures`), and `tools/check-size-buffers` (`size-buffers` against `scripts/fixtures/buffers`, plus the numbers that `concepts/network-buffers.md` prints) |
| `make lint-docs` | `GLOSSARY.md` ids are unique and sorted (`tools/check-glossary`), relative links and `#anchors` resolve, every Mermaid block parses (mermaid-cli, required in CI), SVG rules from `STYLE.md` §3.5 (size, title and desc, viewBox, fonts of 10px or more, loops of 4 to 10 s, dark-mode and reduced-motion blocks), no orphan SVG, no image without alt text, a blank line after every "Picture it" quote |
| `make lint-site` | `site/` pages load nothing from another origin, links and images exist, alt text, `tools/check-explorer` and `tools/check-buffers` (Node, required in CI) hold `site/layout.js` and `site/buffers.js` to the same golden files as `plan-layout` and `size-buffers` |
| `make site` | assembles `_site/` for a local preview (`python3 -m http.server --directory _site`), including `diagrams.json`, the list of diagrams and the pages that use them, which the gallery reads |
| `make lint-java` | Checkstyle, `-Werror` compile, dependency approval, checksums |
| `make check-scripts` | every guide script end to end on the fake hosts in `scripts/fixtures/hosts`: plan, dry-run, apply, simulated reboot, verify, every rollback, and what the rollback left behind. The transcript must equal `expected` (`tools/check-scripts --update` rewrites it). Linux only, so it is not part of `make lint`. CI runs it in UBI 8, 9 and 10 containers (`.github/workflows/integration.yml`) |
| `make check-script-regressions` | focused regressions for script prechecks and restoration, using the same fake hosts as Level 1. Linux only; also run by `tools/check-scripts` and the container checker |
| `make check-containers` | the guides in a systemd container of each RHEL-family image (UBI 8, 9 and 10, Rocky 8 and 9, AlmaLinux 10, and CentOS Stream 9 and 10 as advisory): real `systemctl`, `grubby` and `tuned-adm` where the package exists, a fake `/proc` and `/sys`. `systemd-analyze verify` on every unit, a fake versus real `grubby` comparison, then apply, reboot, verify and rollback. Known script bugs are in `scripts/fixtures/containers/known-issues`: a bug that is not listed fails, and so does a listed bug that no longer shows up. Needs podman or docker, so it is not part of `make lint`. CI runs it in `.github/workflows/integration.yml` |
| `make check-vm` | the guides on a real kernel (Level 3): each cloud image (Rocky 8 and 9, AlmaLinux 10, and CentOS Stream 10 as advisory; Stream 9 is left out while CentOS publishes no checksum for it) boots in QEMU/KVM with 4 vCPUs on 2 NUMA nodes and two virtio-net NICs. Twice, as a VM and forced to `bare_metal`: apply, reboot, check `/proc/cmdline`, per-node huge pages and `verify-tuning --report`, roll back every guide, reboot, and compare with the state before apply. Known script bugs are in `scripts/fixtures/vm/known-issues` (same rules as the containers list), the WARNs a VM is expected to show in `scripts/fixtures/vm/expected-warnings`. Linux with `/dev/kvm` only, so it is not part of `make lint`. CI runs it in `.github/workflows/vm.yml` on script and tool changes and nightly |
| `doc-health` workflow | CI only, `.github/workflows/doc-health.yml`: on every PR and push to `main`, Lychee checks the links and fragments of the Markdown files and of the assembled site offline, and misspell (US locale) checks their text. Weekly and on demand it also checks the live external links. Both tools are pinned release binaries with a checked SHA-256 |
| `make install-git-hooks` | opt-in hooks: pre-commit runs `make lint`, commit-msg runs `tools/check-commit-title` and `tools/check-description` |
| `tools/check-commit-title` | Conventional Commits titles with a Google-style subject (§8). CI checks every PR title and commit |
| `tools/check-description` | no emojis, tool footers or tool co-author trailers in PR and commit descriptions (§8). CI checks the PR body and every commit |

## 8. Git

- **Commit titles** use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) types with a subject written to Google's guidance for change descriptions. PR titles follow the same rules, because a squash merge turns the PR title into the commit title, and a rebase merge keeps every commit, so each commit title and description follow them too. `tools/check-commit-title` enforces them.
  - Format `type(scope)!: subject`. `type` is one of `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`. The scope and `!` (breaking change) are optional. No ticket prefix.
  - The subject completes "If applied, this commit will ...": imperative and lowercase, `docs(network): add ethtool reference`, not `docs(network): Added ethtool reference`.
  - Specific: `fix: pin IRQs of bulk NICs to housekeeping CPUs`, not `fix: bug` or `chore: update files`.
  - At most 72 characters, no trailing period, ASCII only.
  - A body is optional. When there is one, leave a blank line after the title and explain what changed and why, wrapped at 72 columns.
- **Descriptions** (PR bodies and commit bodies) are plain text: no emojis, no tool attribution footers such as "Generated with ...", and no `Co-authored-by:` trailers naming a coding tool. `tools/check-description` enforces this in the commit-msg hook and in CI.
- [Conventional Branch](https://conventional-branch.github.io/) names: `<type>/<kebab-slug>` (`docs/kernel-bypass`, `fix/irq-affinity`).
- Work lands on `main` through pull requests. Never push directly to `main`.
