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
make site                     # optional: assemble _site/ to preview the site locally
```

- `make check-scripts` needs Linux. On macOS or Windows, run it in a UBI container: `podman run --rm -v "$PWD:/repo:Z" -w /repo registry.access.redhat.com/ubi9/ubi bash -c 'dnf -y -q install diffutils && tools/check-scripts'`. If a script change alters its behavior, `tools/check-scripts --update` rewrites the transcripts in `scripts/fixtures/hosts/*/expected`. Review that diff: it shows exactly what the change does on a host.
- Work lands on `main` through pull requests. Never push directly to `main`.
- One change per pull request.
- Both squash and rebase merges are enabled. A squash merge turns the PR title into the commit title, and a rebase merge keeps every commit, so every commit title and the PR title follow the same rule. Use `type(scope): subject`, imperative and lowercase, at most 72 ASCII characters. `tools/check-commit-title` enforces it, and the full rules are in [AGENTS.md section 8](AGENTS.md#8-git).
- PR and commit descriptions are plain text: no emojis, no tool attribution footers. `tools/check-description` enforces it.

## Reporting wrong or dangerous advice

Open an issue with the guide and section, what the text says, what you observed, and the kernel and hardware. If the advice can lock a host out or weaken security, read [SECURITY.md](SECURITY.md) first.

## License of contributions

Prose is [CC BY 4.0](LICENSE-docs) and code is [MIT](LICENSE). By contributing you agree that your change is released under the license of the files it touches.
