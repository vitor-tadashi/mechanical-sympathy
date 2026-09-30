# Contributing

Thank you for reading closely enough to want to fix something. This repository is a set of guides plus the scripts that apply them, so a wrong sentence can misconfigure a host. Corrections are the most valuable contribution.

## Before you start

- Read [AGENTS.md](AGENTS.md). The rules there apply to every change, whoever makes it: keep it generic, explain the why, one script per guide, ShellCheck clean.
- Read [STYLE.md](STYLE.md) for the page skeleton, diagrams and the accessibility checklist.
- For a new guide or a large rewrite, open an issue first and describe the goal and what is out of scope.

## Ground rules in one screen

| Do | Do not |
|---|---|
| Explain what a setting does, why this value, how to verify it and how to roll it back | Ship an outline or a bare list of values |
| Mark advice you have not seen in production | Present a guess as fact |
| Use the neutral names (`critical`, `bulk`, `/opt/lowlat`, `app-user`) | Add real host names, IP addresses, employers, customers or logs |
| Show numbers with a unit and label them illustrative unless you measured them | Invent benchmark results |
| Use American English | Add `.sh` extensions or Maven files |

## Workflow

```bash
make install-git-hooks        # optional: pre-commit runs make lint, commit-msg checks titles
git switch -c docs/short-slug # Conventional Branch: <type>/<kebab-slug>
make lint                     # links, anchors, Mermaid, SVG rules, ShellCheck, site, Checkstyle
make check-scripts            # script changes: every script end to end on fake hosts (Linux only)
make check-containers         # script changes: the same in systemd containers of RHEL-family images (podman or docker)
make check-vm                 # script changes: the same on a real kernel in KVM guests (Linux with /dev/kvm; CI runs it)
make site                     # optional: assemble _site/ to preview the site locally
```

- `make check-scripts` needs Linux. On macOS or Windows, run it in a UBI container: `podman run --rm -v "$PWD:/repo:Z" -w /repo registry.access.redhat.com/ubi9/ubi bash -c 'dnf -y -q install diffutils && tools/check-scripts'`. If a script change alters its behavior, `tools/check-scripts --update` rewrites the transcripts in `scripts/fixtures/hosts/*/expected`. Review that diff: it shows exactly what the change does on a host.
- `make check-containers` runs the guides in a container of each RHEL-family image, with systemd as PID 1. On macOS: `brew install podman && podman machine init && podman machine start`, then `tools/check-containers ubi9` for one image (also `ubi8`, `ubi10`, `rocky8`, `rocky9`, `alma10`, `stream9`, `stream10`). Locally it uses your CPU architecture, and CI uses `linux/amd64`. It prints one PASS or FAIL line per image and keeps the logs in a directory it names. A bug of the scripts that is already known lives in `scripts/fixtures/containers/known-issues`. Delete its line in the change that fixes it: the check fails for a listed bug that no longer shows up.
- `make check-vm` boots each cloud image in QEMU/KVM, applies the guides, reboots, verifies, rolls back, reboots again, and compares with the state before apply. It needs Linux with a usable `/dev/kvm` and `sudo` for one tap device, so on macOS leave it to CI (`.github/workflows/vm.yml`, which also runs it nightly). `tools/check-vm rocky9` checks one image (also `rocky8`, `alma10`, `stream10`, and `stream9` once CentOS publishes a checksum for it again: the check boots no image it cannot verify). Its known bugs live in `scripts/fixtures/vm/known-issues`, with the same rules.
- Work lands on `main` through pull requests. Never push directly to `main`.
- One change per pull request.
- Both squash and rebase merges are enabled. A squash merge turns the PR title into the commit title, and a rebase merge keeps every commit, so every commit title and the PR title follow the same rule. Use `type(scope): subject`, imperative and lowercase, at most 72 ASCII characters. `tools/check-commit-title` enforces it, and the full rules are in [AGENTS.md section 8](AGENTS.md#8-git).
- PR and commit descriptions are plain text: no emojis, no tool attribution footers. `tools/check-description` enforces it.

## Dependency updates

### At a glance

- **What:** [Dependabot](GLOSSARY.md#dependabot) proposes workflow action and Java probe updates weekly.
- **Approval:** The owner approves library and build-tool changes, and every merge.
- **Verification:** Keep action pins and review Gradle checksums before merging.

[The configuration](.github/dependabot.yml) checks both ecosystems on Mondays at 07:23 UTC and allows three open version-update PRs per ecosystem. GitHub handles security-update PRs separately; [that limit does not cover them](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference#open-pull-requests-limit). Automatic rebasing is disabled. Resolve conflicts by merging main when the owner requests it.

### Workflow actions

Keep every action pinned to a full commit SHA with its release version in a trailing comment. Confirm the commit against the upstream release, run `make lint`, and inspect the workflow's CI run. Titles and descriptions follow [the same rules](AGENTS.md#8-git) as any other PR, including copied release notes.

### Java probe

1. Get the owner's explicit approval for library versions, new transitive libraries, and build-tool or plugin changes. Record that approval even when the bot edits `approvedDependencies`.
2. Align `approvedDependencies` in `build.gradle.kts` with the approved compile and runtime dependencies. For wrapper changes, review `distributionUrl` and `distributionSha256Sum` and keep the Gradle version in `.sdkmanrc` aligned.
3. After approval, regenerate verification metadata locally and review every newly trusted artifact in the diff:

   ```bash
   cd examples/java-latency-probe
   sdk env
   ./gradlew --write-verification-metadata sha256 check
   git diff origin/main -- build.gradle.kts gradle/verification-metadata.xml gradle/wrapper/gradle-wrapper.properties .sdkmanrc
   ./gradlew check
   cd ../..
   make lint
   ```

4. Commit the reviewed approval-list and checksum changes together, using signed commits. Both Gradle checks and `make lint` must pass; inspect the CI result before requesting a merge.

A Gradle update can fail until its approval list and checksums have been reviewed. Generating checksums does not approve a library. Keep dependency verification enabled; CI runs the ordinary check and never generates trust metadata. All dependency PRs need manual review and an owner-approved merge.

To stop version-update PRs, set the affected ecosystem's `open-pull-requests-limit` to `0` in a reviewed PR. Security-update settings remain an owner decision in repository settings.

## Reporting a run on real hardware

### At a glance

- **What:** a report of what happened when you ran the scripts or a guide on a real server, or on a VM you own.
- **Why:** the harnesses in CI run on fake hosts, in containers and in VMs. They cannot show BIOS behavior, physical NIC features or a real workload. Only a report from real hardware can.
- **Where:** open an issue with the [hardware report form](.github/ISSUE_TEMPLATE/hardware-report.yml).

**What to run:**

```bash
uname -r
sudo scripts/verify-tuning --report verify-report.txt
```

The report file starts with a `host:` line that holds your host name: replace it before you paste or attach the file.

**What to leave out:** host names, IP and MAC addresses, serial numbers, asset tags, user names and internal paths. The form has a required box for it. Do not send a report that you cannot sanitize.

**What a report is, and is not:** it is evidence about one host on one day. It is not a certification, and this project does not issue or claim one. A report of a failure is as useful as a report of a success. Numbers need the tool, the workload and the units, or they are not used.

## Reporting wrong or dangerous advice

Open an issue with the guide and section, what the text says, what you observed, and the kernel and hardware. If the advice can lock a host out or weaken security, read [SECURITY.md](SECURITY.md) first.

## License of contributions

Prose is [CC BY 4.0](LICENSE-docs) and code is [MIT](LICENSE). By contributing you agree that your change is released under the license of the files it touches.
