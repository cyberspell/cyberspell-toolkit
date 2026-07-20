# Security Policy

## Reporting a vulnerability

If you find a security issue in Cyberspell Toolkit (e.g. a command that could be abused,
an injection path through a prompt, or a problem with the loader/Worker delivery chain),
please **do not open a public issue**.

Report it privately via the contact options at [jp.cyberspell.cloud](https://jp.cyberspell.cloud),
or use GitHub's *"Report a vulnerability"* (Security tab) on the repo.
You'll get an acknowledgment, typically within a few days.

## Scope notes

- The toolkit intentionally runs administrative commands **locally, at the operator's
  request, with confirmation gates** "it can restart the spooler" is a feature, not a
  finding. In scope: anything that lets the toolkit do something the operator did *not*
  ask for, escalates beyond the session's rights, or tampers with the delivery chain.
- The published script is served from `dist/toolkit.ps1` on the `main` branch via
  Cloudflare. Verifying independently is easy:
  compare `irm https://cyberspell.cloud/toolkit` against the repo file.

## Supported versions

Only the latest release on `main` is supported. There is no backporting.