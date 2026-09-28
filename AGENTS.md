# Agent guidance

Generic low-latency tuning guides for RHEL 8/9 bare metal and VMs. Each guide in `guides/NN-*.md` has one script `scripts/NN-*` that applies, verifies and rolls it back. `concepts/` explains the mechanisms, and `examples/` holds worked examples, including a runnable Java probe (`examples/java-latency-probe/`, which has its own `CLAUDE.md`).

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
- Advice that has not been proven in production is marked as such in the text.
- American English in every committed file.

## 4. Tuning stance

- Huge pages for latency JVMs: explicit hugetlbfs, reserved per NUMA node at early boot. Never transparent huge pages (`transparent_hugepage=never`).
- IRQs and softirqs of kernel-stack NICs never run on isolated CPUs.
- Every runtime (non-persistent) setting is re-applied at boot by `lowlat-runtime.service`.

## 5. Shell scripts

- **No file extension.** Name the file after its purpose (`04-network`, `verify-tuning`), start it with `#!/usr/bin/env bash`, `set -Eeuo pipefail`, and `chmod +x`. Sourced files (`scripts/lib/*`, `lowlat.conf*`) are not executable.
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
| `make lint-scripts` | no `.sh`/`.bash` files, exec bits, ShellCheck `enable=all`, `bash -n` |
| `make lint-java` | Checkstyle, `-Werror` compile, dependency approval, checksums |
| `make install-git-hooks` | opt-in hooks: pre-commit runs `make lint`, commit-msg runs `tools/check-commit-title` and `tools/check-description` |
| `tools/check-commit-title` | commit and PR title rules (section 8). CI checks every PR title and commit |
| `tools/check-description` | no emojis or tool footers in PR and commit descriptions (section 8). CI checks the PR body and every commit |

## 8. Git

- **Commit titles** follow Google's guidance for change descriptions. The title completes "If applied, this commit will ...". PR titles follow the same rules, because a squash merge turns the PR title into the commit title.
  - Imperative mood, capitalized: `Add kernel-bypass guide`, not `Added kernel-bypass guide` or `add kernel-bypass guide`.
  - Plain text, no prefix: no `docs:`, `feat(scope):` or `[TICKET]`.
  - At most 72 characters, no trailing period, ASCII only.
  - Specific: `Pin IRQs of bulk NICs to housekeeping CPUs`, not `Fix bug` or `Update files`.
  - A body is optional. When there is one, leave a blank line after the title and explain what changed and why, wrapped at 72 columns.
- **Descriptions** (PR bodies and commit bodies) are plain text: no emojis and no tool attribution footers such as "Generated with ...". `tools/check-description` enforces this in the commit-msg hook and in CI.
- [Conventional Branch](https://conventional-branch.github.io/) names: `<type>/<kebab-slug>` (`docs/kernel-bypass`, `fix/irq-affinity`).
- Work lands on `main` through pull requests. Never push directly to `main`.
