# Contributing

PurrType is a local-first macOS input method. Changes should preserve predictable typing behavior, low latency, privacy, and redistributable table data.

## Development Setup

Required tools:

```sh
xcrun --show-sdk-path
clang --version
make --version
```

Run the focused test suite before sending a change:

```sh
make test
```

Run the full non-GUI release validation before release-candidate or packaging changes:

```sh
make release-preflight
```

Run the focused license/privacy packaging audit after changing bundled data,
acknowledgements, installer packaging, or release docs:

```sh
make license-audit
```

## Change Guidelines

- Keep runtime behavior changes small and covered by tests.
- Do not vendor proprietary or unclear-license input tables.
- Do not add network calls to core input, learning, ranking, or candidate generation.
- Do not log full user input, secrets, credentials, private keys, authorization tokens, banking details, IDs, addresses, or other sensitive text.
- Keep Sucheng fixed-position behavior stable unless a reviewed compatibility guard requires a change.
- Keep New Sucheng learning opt-in, local, and privacy-preserving.

## Manual Release Checks

Use the full checklist in `docs/MANUAL_QA.md` for release candidates.

After `make release-preflight`, install from the generated DMG/pkg and test:

- TextEdit
- Safari
- Notes
- Terminal
- System Settings input-source add/select flow
- Sucheng, New Sucheng, Cangjie, and Pinyin mode switching
- Escape, Backspace, Enter, Space, Tab, number selection, and `0` raw-English candidate behavior
- Privacy Lock, reset learning, and secure input prompts
- DMG `Install PurrType.pkg` and `Uninstall PurrType.pkg`
- installed app bundle Legal resources and upstream license files
