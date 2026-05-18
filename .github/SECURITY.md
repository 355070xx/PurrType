# Security Policy

PurrType processes input locally and should not require network access for typing, ranking, learning, or candidate generation.

## Reporting

For private or sensitive issues, do not attach raw user input, passwords, tokens, private keys, banking details, IDs, addresses, or authorization material to public issues. Mask sensitive values as `***`.

Report security-sensitive findings directly to the repository owner through a private channel before opening a public issue.

## Supported Scope

Security and privacy reports are in scope when they involve:

- unintended capture or storage of sensitive input
- unmasked logs or crash output containing user text or credentials
- unexpected network access from the input method
- unsafe package install or uninstall behavior
- bundled third-party data with unclear redistribution terms

General candidate ordering, typing behavior, or UI bugs should use the bug report template.
