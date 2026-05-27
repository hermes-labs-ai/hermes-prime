# Security Policy

## Supported Versions

`hermes-prime` is v0.1.x — alpha. The runtime surface is a single bash script (~120 LOC) plus a markdown fragment. No network calls, no credential handling, no executable code in the fragment, no user-data storage. The surface area for security vulnerabilities is small but not zero.

## Reporting a Vulnerability

Email: **roli@hermes-labs.ai** with subject line `[security] hermes-prime`.

Do not open public GitHub issues for security reports.

We will acknowledge within 72 hours. If the issue is valid, we will ship a fix in the next patch release and credit the reporter (unless anonymous is preferred).

## Threat Model (v0.1.x)

What this package guards against:

- None directly. This is a session-priming utility, not a security tool.

What this package does **not** defend against:

- **Path injection** — `--inject <project>` writes to `<project>/CLAUDE.md`. Callers passing untrusted `<project>` strings are responsible for sanitizing. The script does check `[[ -d "$proj" ]]` but does not guard against symlink races on multi-user systems.
- **Marker-collision attack** — a project's pre-existing `CLAUDE.md` containing `<!-- session-init: BEGIN -->` will be treated as already-injected. An adversary who can write the marker into a target's `CLAUDE.md` can prevent injection. This is a denial-of-priming, not an exploit.
- **Fragment tampering** — if the local handbook copy or the repo-local `CLAUDE-fragment.md` is modified by an attacker, injected content reflects the modification. The `.hermes-seal.yaml` manifest detects tampering at the repo level via `hermes-seal verify .`.
- **Backup-file disclosure** — `--inject` writes `CLAUDE.md.bak.<timestamp>` next to the target. Backups are not gitignored by default. Callers handling sensitive content in pre-existing `CLAUDE.md` should review their `.gitignore`.

## Verification

Repos shipping hermes-prime can be verified end-to-end via Hermes Seal:

```bash
hermes-seal verify .
```

Exit 0 = manifest valid + file hashes match. Non-zero = tampered, invalid, or revoked.
