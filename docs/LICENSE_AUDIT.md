# License Audit

Audit date: May 15, 2026

This audit records the license and redistribution status for PurrType's source
tree, runtime package, and bundled dictionary/table data.

## Summary

PurrType's original source code is MIT licensed. Runtime builds also bundle
third-party input tables and dictionary data under their own upstream licenses
or terms. Do not describe the whole binary payload as MIT-only.

Current release posture:

- source repository: OK to publish with `LICENSE`, `docs/CREDITS.md`,
  and vendored upstream license/attribution files
- unsigned local package/DMG: OK for source-first testing when acknowledgements remain
  bundled
- prebuilt public binary: include bundled Legal resources, checksums,
  provenance, and third-party license files; use signed/notarized artifacts for
  distribution outside source builds

This is an engineering audit, not legal advice.

## Code And Dependency Scope

Current codebase review scope:

- Objective-C source under `src/` and test/audit programs under `tests/`.
- POSIX shell, Ruby, and Python helper scripts under `scripts/` and
  `packaging/`.
- Runtime resources under `resources/`.
- Vendored dictionary/table data under `third_party/`.
- Release and user-facing docs under `docs/`, repository root, and
  `packaging/README.txt`.

Builds link only against Apple system frameworks and SDK libraries available on
macOS, including Cocoa, InputMethodKit, Carbon, Foundation, and CommonCrypto.
Those Apple system frameworks are not redistributed as third-party source in
this repository. The project does not use npm, Cargo, CocoaPods, Swift Package
Manager, Homebrew vendored libraries, or other package-manager dependencies.

## Runtime Redistribution Status

| Component | Runtime status | License / terms signal | Required action |
| --- | --- | --- | --- |
| PurrType original source | bundled as app binary | MIT | Keep `LICENSE` with source and release artifacts. |
| IBus Cangjie5 table | bundled | table header says freely redistributable without restriction | Keep `third_party/ibus-table-chinese/LICENSE` and `README.md`. |
| IBus Quick Classic table | bundled | table header says freely redistributable without restriction | Keep `third_party/ibus-table-chinese/LICENSE` and `README.md`. |
| Rime Cangjie base/extended dictionaries | bundled | dictionary headers say `License: GPL`; upstream directory includes LGPL-3.0 license text and authors | Treat as copyleft/upstream-licensed dictionary data; keep `LICENSE` and `AUTHORS`; do not present binary payload as MIT-only. |
| Rime Luna Pinyin dictionary | bundled | upstream directory includes LGPL-3.0 license text and authors, with additional attribution notes | Keep `LICENSE` and `AUTHORS`; do not strip attribution comments. |
| McBopomofo associated phrase data | source/generation input; derived association data bundled | MIT | Keep `third_party/mcbopomofo/LICENSE.txt`; bundle `MCBOPOMOFO_LICENSE.txt` with Legal resources because `association_generated.tsv` derives from this associated phrase source. |
| DATA.GOV.HK HKSCS JSON | bundled | DATA.GOV.HK terms reference | Keep `TERMS.md` and source attribution. |
| Chinese Open Desktop CIN table `mscj3.cin` | source/audit only, not runtime | CC0-1.0 | Keep license in source tree; package smoke rejects runtime redistribution. |
| Generated association data | bundled | generated from project seed data, McBopomofo associated phrase data, typing corpora, IBus table text, and Rime dictionary text | Keep generation script and acknowledgements; regenerate only through `make update-association-seeds`. |

## Installer And Uninstaller Materials

The release DMG root should stay focused on the direct install flow:

```text
README.txt
Install Guide.html
Install PurrType.pkg
Uninstall PurrType.pkg
```

The installer and uninstaller scripts remove only PurrType app bundles,
Launch Services registrations, and matching dev package receipts by
default. They must not remove the public `/Library/Input Methods/PurrTypeIM.app`
bundle or public package receipt. `Uninstall PurrType.pkg` preserves PurrType preferences and New
Sucheng learning data. The source-tree `packaging/Uninstall-PurrType.command`
keeps the explicit `--purge-user-data` path for developer QA.

Legal, credits, and privacy materials remain in the source repository
and in the installed app bundle resources; they are not duplicated at the DMG
root.

## Release Requirements

The app bundle must include:

```text
Contents/Resources/Legal/LICENSE.txt
Contents/Resources/Legal/CREDITS.md
Contents/Resources/Legal/PRIVACY_POLICY.md
Contents/Resources/Legal/LICENSE_AUDIT.md
Contents/Resources/Legal/MCBOPOMOFO_LICENSE.txt
```

The app bundle must also keep upstream runtime license/attribution files:

```text
Contents/Resources/IBusTableChinese/LICENSE
Contents/Resources/IBusTableChinese/README.md
Contents/Resources/RimeCangjie/LICENSE
Contents/Resources/RimeCangjie/AUTHORS
Contents/Resources/RimePinyin/LICENSE
Contents/Resources/RimePinyin/AUTHORS
Contents/Resources/HKSCS/TERMS.md
Contents/Resources/HKSCS/README.md
```

The runtime bundle must not accidentally include audit-only or stale resources:

```text
Contents/Resources/CINTables
Contents/Resources/RimeCangjie/cangjie5.dict.yaml
Contents/Resources/RimeCangjie/cangjie5_express.schema.yaml
Contents/Resources/ranking_overrides.tsv
Contents/Resources/legacy_sucheng_overrides.tsv
```

## Audit Commands

Run the focused audit:

```sh
make license-audit
```

Run packaging verification:

```sh
make package-smoke
```

Run full non-GUI release validation:

```sh
make release-preflight
```

`make license-audit` expands the package payload and verifies the runtime Legal
resources, upstream license files, acknowledgement text, focused DMG root,
uninstall package script, and exclusion of audit-only runtime data.

For shell syntax after installer or uninstaller edits:

```sh
sh -n scripts/install-local.sh scripts/uninstall-local.sh scripts/uninstall-system.sh \
  scripts/repair-installed-input-source.sh scripts/audit-license-notices.sh \
  packaging/scripts/preinstall packaging/scripts/postinstall \
  packaging/uninstall-scripts/postinstall packaging/Uninstall-PurrType.command
```

## Known Caveat

The Rime Cangjie dictionary files used at runtime contain `License: GPL` in the
dictionary headers while the vendored upstream directory includes LGPL-3.0
license text. Until this is resolved upstream or replaced with a clearer source,
PurrType should keep the files and acknowledgements intact and avoid claiming the
redistributed binary payload is MIT-only.
