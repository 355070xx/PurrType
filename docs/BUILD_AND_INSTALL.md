# Build And Install

## Normal User Install

Use the packaged installer for normal testing and releases. No Terminal commands are required for this path:

1. Open `PurrType-0.1.0.dmg`.
2. Double-click `Install PurrType.pkg`.
3. Complete the macOS Installer flow.
4. Quit and reopen System Settings if it was already open.
5. Open `System Settings > Keyboard > Text Input > Edit...`.
6. Add `PurrType`.

The package installs to:

```text
/Library/Input Methods/PurrTypeIM.app
```

macOS may ask for an administrator password because this is a system Input Methods location.
The package registers the input method bundle with macOS, but it does not enable
or add `PurrType` for the user. Add it manually from Text Input so the input
source permission remains an explicit user action.

## Supported Runtime Scope

The current runtime supports one macOS-visible `PurrType` input method with four internal modes:

- `Sucheng`
- `New Sucheng`
- `Cangjie`
- `Pinyin`

English is handled by automatic raw English pass-through instead of a separate selectable mode. Future English spelling suggestions are planned only after the current input methods are complete; they must be candidate suggestions, not automatic autocorrect.

## Requirements

- macOS
- Xcode Command Line Tools
- `clang`
- `codesign`
- `make`

Check tools:

```sh
xcrun --show-sdk-path
clang --version
make --version
```

## Build

```sh
make build
```

The build creates:

```text
build/PurrTypeIM.app
```

The bundle is ad-hoc signed for local testing.

To remove generated app bundles, packages, disk images, test binaries, and Finder metadata:

```sh
make clean
```

## Run Tests

```sh
make test
```

Current tests validate:

- IBus Cangjie5 table loading.
- IBus Quick Classic Sucheng table loading.
- DATA.GOV.HK HKSCS overlay loading for Hong Kong-specific Cangjie and Sucheng characters.
- Rime Cangjie dictionary loading.
- Pinyin seed table loading.
- Engine startup benchmark confirming Classic Sucheng loads first while Cangjie and Pinyin dictionaries stay deferred until first lookup.
- Basic candidate lookup.
- Traditional-only candidate filtering for Simplified-only characters.
- Quick Classic Sucheng ordering for common candidates such as `hi` -> `我` at slot 7.
- Verified Sucheng order guards for high-impact legacy first-page candidates.
- Sucheng first-page golden snapshot for all populated alphabetic one/two-key codes.
- Association candidate lookup.
- Association phrase seed loading from `resources/association_phrases.tsv`.
- Generated association index lookup from `resources/association_generated.index`.
- Full-phrase association lookup before single-character fallback, such as `可以` -> `用`.
- Multi-character association suffixes, such as `輸` -> `入法`.
- Sucheng ignores local learning and keeps fixed positions.
- New Sucheng applies optional hashed local candidate and association ranking.
- New Sucheng learns committed user phrases with their actual typed Sucheng code when available.
- New Sucheng phrase seed composition for long code streams such as `hionaomjoo`.
- New Sucheng auto phrase seed generation from association phrases such as `中文輸入法`.
- Expanded New Sucheng association phrase corpus such as `今日開始`.
- Cached preferred Sucheng code lookup for scalable corpus-generated phrases.
- New Sucheng association-aware generated phrase beam with hashed local ranking.
- New Sucheng committed custom phrase session learning.
- URL-like raw token detection.
- Input behavior regression for mode shortcuts, preferences shortcut, candidate paging, `0` raw-English candidate display, and Shift temporary English.
- One-hour equivalent typing simulation from `docs/typing/one_hour_typing_corpus.md`, including Sucheng candidate selection, candidate page turns, mixed English raw text, Cangjie replay, New Sucheng custom phrase session replay, preference toggle behavior, and exact output comparison.

After installing a development or package build, verify that macOS Text Input Sources can see the input method:

```sh
make tis-probe TIS_ID=org.purrtype.inputmethod.PurrTypeUnified
make tis-inspect
```

Expected output includes:

```text
id=org.purrtype.inputmethod.PurrTypeUnified name=PurrType
count=1
```

If System Settings shows PurrType entries but they do not appear in the menu bar input menu, enable the parent input source with Apple's Text Input Sources API:

```sh
make enable
```

For manual development testing, select it directly:

```sh
make select
```

## Install Locally

For source-tree development, use the local install target. It copies the bundle,
registers the input source, enables it for the current user, and refreshes the
input menu cache. It may still require a logout before macOS refreshes the Text
Input Sources list.

```sh
make install
```

This copies the built bundle to:

```text
~/Library/Input Methods/PurrTypeIM.app
```

The installer also removes the old prototype bundle if present:

```text
~/Library/Input Methods/PurrTypeInput.app
~/Library/Input Methods/PurrType.inputmethod
```

Then open:

```text
System Settings > Keyboard > Text Input > Edit...
```

Confirm the input source is present:

```text
PurrType
```

If it does not appear, log out and back in, then check the input source list again.

## Stop A Running Development Copy

`PurrTypeIM.app` is a background-only input method server. If you double-click it in Finder, it may start without showing any window.

Stop it with:

```sh
make stop
```

Or use Activity Monitor and search for:

```text
PurrType
```

## Remove Installs

If repeated package installs left stale PurrType bundles behind, run:

```sh
make uninstall-system
```

This removes only PurrType bundles and package receipts owned by this project:

```text
/Library/Input Methods/PurrTypeIM.app
/Library/Input Methods/PurrTypeIM.localized
/Library/Input Methods/PurrTypeInput.app
/Library/Input Methods/PurrType.app
/Library/Input Methods/PurrType.inputmethod
/Library/Application Support/PurrType/PurrTypeIM.app
```

## Build DMG And PKG Installer

If you previously used the development install target, remove that user-level install before testing the package:

```sh
make uninstall-local
```

```sh
make package
```

This creates:

```text
build/PurrType-0.1.0.pkg
build/PurrType-0.1.0.dmg
```

Before manually installing a test package, run the non-GUI release preflight:

```sh
make release-preflight
```

This runs the normal test suite, version consistency audit, the full Bible typing audit, package build, package payload inspection, required resource checks, input source metadata checks, and DMG metadata validation. It does not install or select the input method.

For only the package and DMG inspection step:

```sh
make package-smoke
```

For the focused privacy/license packaging audit:

```sh
make license-audit
```

This expands the package payload and verifies that installed Legal resources,
runtime upstream license files, acknowledgements, and audit-only resource
exclusions are correct.

Current packages are unsigned local test artifacts. This is enough for source-first GitHub distribution where users clone the repository and build locally. If you publish prebuilt `.pkg` or `.dmg` files for non-developer users, Developer ID signing and DMG notarization are recommended to avoid Gatekeeper warnings.

To generate unsigned release artifacts plus SHA-256 checksums and provenance metadata:

```sh
make release-artifacts
shasum -a 256 -c build/PurrType-0.1.0-checksums.sha256
```

This writes:

```text
build/PurrType-0.1.0.pkg
build/Uninstall-PurrType-0.1.0.pkg
build/PurrType-0.1.0.dmg
build/PurrType-0.1.0-checksums.sha256
build/PurrType-0.1.0-provenance.json
```

The DMG root contains:

```text
README.txt
Install PurrType.pkg
Uninstall PurrType.pkg
```

Legal, acknowledgement, and privacy materials are kept in the source repository
and inside the installed app bundle under `Contents/Resources/Legal`; they are
not duplicated at the DMG root.

For an optional prebuilt binary release, import valid Apple Developer ID certificates into the login keychain and store a notarytool credential profile first:

```sh
xcrun notarytool store-credentials PurrTypeNotary
```

Then build, sign, notarize, staple, verify, and generate signed checksums/provenance:

```sh
make release-signed \
  DEVELOPER_ID_APPLICATION_IDENTITY="Developer ID Application: Example (TEAMID)" \
  DEVELOPER_ID_INSTALLER_IDENTITY="Developer ID Installer: Example (TEAMID)" \
  NOTARY_KEYCHAIN_PROFILE="PurrTypeNotary"
```

The signed release path is not required for source-only GitHub releases. It fails before modifying artifacts if the Developer ID identities or notarytool profile are missing. A successful signed binary release writes:

```text
build/PurrType-0.1.0-signed.pkg
build/Uninstall-PurrType-0.1.0-signed.pkg
build/PurrType-0.1.0-signed.dmg
build/PurrType-0.1.0-signed-checksums.sha256
build/PurrType-0.1.0-signed-provenance.json
```

Verify the signed DMG:

```sh
xcrun stapler validate build/PurrType-0.1.0-signed.dmg
spctl -a -vv -t open --context context:primary-signature build/PurrType-0.1.0-signed.dmg
```

Use this path for normal testing:

1. Open `build/PurrType-0.1.0.dmg`.
2. Double-click `Install PurrType.pkg`.
3. Complete the installer.
4. Quit and reopen System Settings if it was already open.
5. Open `System Settings > Keyboard > Text Input > Edit...`.
6. Add `PurrType`.

`PurrType` is registered as one macOS input source. New installs default to
`Sucheng`; use the PurrType menu UI, mode shortcuts, or `PurrType Preferences...`
window to switch internally between `Sucheng`, `New Sucheng`, `Cangjie`, and
`Pinyin`.
Press `Ctrl+Shift+,` while PurrType is active to open or refocus the
preferences window. When the preferences helper is active, `Cmd+,` also shows
the preferences window, `Cmd+W` closes it, and `Cmd+Q` quits the helper. The
preferences window opens on `Input Modes` and contains `Input Modes`, `Typing`,
`Privacy & Learning`, and `About`. English typing is handled by automatic raw
English pass-through instead of a separate selectable mode. When a short English
token also has Chinese candidates, the candidate panel lists `0` first so
pressing `0` commits the typed letters unchanged. The preferences window can
enable or disable this `0` raw-English candidate, choose whether Space moves to
the next candidate page, set the Chinese candidate page size to 5 or 9,
customize mode shortcuts, and choose the Privacy Lock shortcut. The selected
mode is saved for the next activation. If an older install had saved `English`
or the removed experimental Quick Classic mode, the next launch falls back to
`Sucheng`. The menu also shows the current mode, mode shortcuts, candidate
paging keys, local learning status, an `Enable New Sucheng Learning` toggle,
`Privacy Lock`, and a reset action for New Sucheng learning. New installs
default this learning toggle to off; users must opt in before New Sucheng
applies hashed local ranking. `Privacy Lock` pauses learning, clears rolling
context, and suppresses post-commit association suggestions without overwriting
the saved learning preference. Existing candidate ranking can persist across
engine restarts; committed custom phrases remain session-only.

Mode shortcuts:

| Shortcut | Mode |
| --- | --- |
| Ctrl+Shift+1 | Sucheng |
| Ctrl+Shift+2 | New Sucheng |
| Ctrl+Shift+3 | Cangjie |
| Ctrl+Shift+4 | Pinyin |
| Ctrl+Shift+, | PurrType Preferences |
| double backtick while idle | Toggle Privacy Lock |

Mode shortcuts can be reassigned in Preferences to `Ctrl+Shift+1` through `Ctrl+Shift+9` or `None`; defaults stay as shown above. Privacy Lock defaults to double backtick while idle, and can be changed to `Ctrl+Shift+\`` or `None`.

The package installs to:

```text
/Library/Input Methods/PurrTypeIM.app
```

This matches the system-level layout used by traditional macOS Chinese input methods.

The package marks `PurrTypeIM.app` as non-relocatable, replaces the previous app bundle, and removes earlier `PurrTypeIM.localized`, `PurrTypeInput.app`, `PurrType.app`, `PurrType.inputmethod`, and invalid `/Library/Application Support/PurrType/PurrTypeIM.app` installs before copying the system-level app. It also forgets stale PurrType package receipts so old prototype package IDs do not linger. When removing stale local development installs, installer and uninstaller scripts resolve the console user's recorded home directory through macOS user records instead of assuming `/Users/<shortname>`. It registers the single `PurrType` input source with macOS, but does not enable or select it for the console user; users add it manually from Text Input. If System Settings was open during installation, quit and reopen System Settings before checking the list.

## Uninstall From DMG

The release DMG includes:

```text
Uninstall PurrType.pkg
```

Double-click it and complete the macOS Installer flow to remove PurrType. It may
ask for an administrator password because the normal package install lives under
`/Library/Input Methods`.

The uninstaller removes:

```text
/Library/Input Methods/PurrTypeIM.app
/Library/Input Methods/PurrTypeIM.localized
/Library/Input Methods/PurrTypeInput.app
/Library/Input Methods/PurrType.app
/Library/Input Methods/PurrType.inputmethod
/Library/Application Support/PurrType/PurrTypeIM.app
```

It also removes matching local development installs for the console user using
the user's recorded home directory. It forgets PurrType package receipts. It
preserves local PurrType preferences and New Sucheng learning data.

To purge local preferences and learning data from a source checkout after
uninstalling:

```sh
sudo packaging/Uninstall-PurrType.command --purge-user-data
```

After uninstalling, quit and reopen System Settings before checking Text Input
sources.

## First Trial Inputs

Try these after selecting `PurrType`. Sucheng is the default mode on a fresh install. Switch mode from the PurrType input menu before trying non-Sucheng examples.

| Input | Expected |
| --- | --- |
| Sucheng: `hi`, then `7` | `我` |
| Sucheng: `bs`, then `6` | `勝` |
| New Sucheng: select `hi` -> `我` once, then type `hi` again | `我` moves to the first candidate in New Sucheng only |
| New Sucheng: `hionao`, then `1` | `我們是` |
| New Sucheng: `hionaom`, then `1` | `我們是一` |
| New Sucheng: `hionaomjoo`, then `1` | `我們是一家人` |
| New Sucheng: `lykjnohei`, then `1` | `中文輸入法` |
| New Sucheng: `onaatvr`, then `1` | `今日開始` |
| New Sucheng: commit `我想繼續` once with code `hidpvivc`, then type `hidpvivc` | `我想繼續` moves to the first candidate in New Sucheng only |
| New Sucheng: `jnohei`, then `1` | `輸入法` |
| New Sucheng: `qnjd`, then `1` | `打字` |
| New Sucheng: `mubw`, then `1` | `電腦` |
| Sucheng: `ms`, then `1` | `功` |
| Cangjie: `hqi`, then `1` | `我` |
| Cangjie: `onf`, then `1` | `你` |
| Cangjie: `mks`, then `1` | `功` |
| Pinyin: `ni`, then `1` | Pinyin candidate `你` |
| Pinyin: `hao`, then `1` | Pinyin candidate `好` |
| after committing `我` | associated candidates such as `們` |
| after committing `候` | associated candidate `選` |
| after committing `排` | associated candidate `位` |
| Sucheng: type `setting`, then Space | commits raw English `setting ` without Chinese candidates after it is recognized as English |
| New Sucheng: type `setting`, then Space | commits raw English `setting ` while still protecting known phrase codes |
| New Sucheng: type `new`, then Space | commits raw English `new ` instead of generated Chinese phrase candidates |
| hold Shift and type `Setting-1`, then Space | temporary raw English composition commits `Setting-1 ` |
| letters then Enter | commit raw English |
| Escape | cancel current composition |
| raw English, then Backspace until empty | exits raw English and lets the next input use the current Chinese mode again |

The candidate panel displays explicit number labels such as `1 功`, `2 勁`; press the matching number key or click the row to select that Chinese candidate. If the current short token can also be kept as English, the panel also shows `0 <typed text>` at the top so `0` or a row click commits the original letters unchanged. When there is more than one candidate page, the panel shows a compact page count such as `1/4` so users can remember where a candidate lives. The custom panel is sized for the configured 5- or 9-candidate page and does not use a scrollbar for normal candidate pages. During composition, the panel follows the marked-text insertion endpoint and prefers the right side of the insertion point, falling above or below only when needed to stay on screen. Post-commit association panels reuse the last composing caret anchor instead of querying the app's transient selected range immediately after commit. Candidate positioning is scheduled once immediately and once shortly after marked-text updates so apps that update caret geometry asynchronously can settle before the final re-anchor.

When no raw-English composition is active, typing punctuation or symbol keys opens a compact open-table candidate panel. `1` keeps the half-width symbol, while later rows expose Traditional Chinese punctuation and full-width symbols such as `，`, `、`, `。`, `…`, `「`, `」`, `《`, `》`, `％`, `＊`, and `＋`. If raw English composition is already active, printable ASCII punctuation stays in the raw English token so email addresses, URLs, paths, code-like text, and English sentences are not interrupted by symbol candidates.

## Long Typing Simulation

The repeatable long-form typing corpus is stored at:

```text
docs/typing/one_hour_typing_corpus.md
```

`make test` runs `PurrTypeTypingSimulationTests`, extracts the text between `TYPING_CORPUS_BEGIN` and `TYPING_CORPUS_END`, repeats it until it reaches the configured one-hour keystroke target, simulates Sucheng code lookup and candidate selection, then verifies Cangjie replay, New Sucheng custom phrase session replay, and the `0` raw-English / Space paging preference toggles. The committed output is compared exactly. The generated run report is:

```text
build/typing-simulation-report.md
```

The same test run also writes a startup report for engine cold-start and first-use lazy loading:

```text
build/engine-startup-report.md
```

For the heavier full Bible coverage audit, run:

```sh
make audit-full-bible
```

That target replays the full CUV Traditional corpus stored at:

```text
docs/typing/full_bible_typing_corpus.md
```

It verifies every CJK character has a Sucheng reverse code, appears in its candidate bucket, lands on a stable candidate page, and displays the expected `1` through `9` label. The generated report is:

```text
build/full_bible_typing_audit.md
```

For fixed Sucheng first-page ranking parity against the bundled Quick Classic source table plus verified guard rows, run:

```sh
make audit-sucheng-ranking
```

The generated report is:

```text
build/sucheng_ranking_audit.md
```

For legacy Traditional Chinese Sucheng and Cangjie parity research, run:

```sh
make audit-legacy-parity
```

This compares current open-table candidate order with bundled proxy sources: `third_party/ibus-table-chinese/quick-classic.txt` for Traditional Simple Cang Jie / Sucheng and `third_party/cin-tables/mscj3.cin` for Cangjie 3 compatibility. It does not use redistributed proprietary dictionary files. User-reported legacy muscle-memory anchors, such as fixed number-key positions, are treated as higher-confidence review signals than the proxy table when they conflict. The generated report is:

```text
build/legacy_parity_audit.md
```

The same audit also writes full machine-readable review queues:

```text
build/legacy_sucheng_first_page_mismatches.tsv
build/legacy_sucheng_slot_diffs.tsv
build/legacy_sucheng_override_suggestions.tsv
build/legacy_sucheng_anchor_conflicts.tsv
build/legacy_cangjie_first_page_mismatches.tsv
build/legacy_cangjie_slot_diffs.tsv
```

`legacy_sucheng_override_suggestions.tsv` only lists rows where the current Sucheng first page and target/proxy first page contain the same nine candidates in a different order, and where the target/proxy order does not conflict with verified anchors. Treat it as a review queue, not an automatic source of truth.

Verified legacy Sucheng fixed-position anchors live in:

```text
resources/sucheng_position_anchors.tsv
```

Those anchors are hard guards for the fixed Sucheng runtime order. For example, the anchors keep `hi` / `竹戈` candidate `我` at position `7`, `得` at position `16` (page 2 slot 7), and `等` at position `19` (page 3 slot 1); proxy rows that disagree are reported but not treated as higher confidence.

If a locally captured legacy first-page table is available, compare against it instead of the bundled proxy:

```sh
LEGACY_SUCHENG_TARGET_TSV=/path/to/legacy_sucheng_first_pages.tsv make audit-legacy-parity
LEGACY_CANGJIE_TARGET_TSV=/path/to/legacy_cangjie_first_pages.tsv make audit-legacy-parity
```

To inspect Sucheng pages for specific codes without launching the input method, run:

```sh
make dump-sucheng-pages CODES="竹戈 人口 口口 卜口 木戈 竹人 人火"
ruby scripts/dump-sucheng-pages.rb --pages 3 hi or rr
```

The dump tool reads the same bundled Quick Classic table and Sucheng order guard file as runtime. It accepts either alphabetic Sucheng codes such as `hi` or Cangjie radical names such as `竹戈`, and prints nine labelled candidates per page.

Candidate paging:

| Key | Action |
| --- | --- |
| Space, Tab, Right Arrow, or PageDown | next candidate page |
| Left Arrow, Shift+Tab, or PageUp | previous candidate page |

Each page shows Chinese candidates labelled by number keys, plus an optional `0` raw-English row. The candidate page size defaults to 9 and can be changed to 5 in `PurrType Preferences... > Input > Candidates per page`. When a composition has more than one candidate page, Space follows the legacy habit and advances to the next page instead of committing the first candidate. This Space paging behavior can be turned off in `PurrType Preferences... > Input`; Tab, Right Arrow, and PageDown still page forward.

## Candidate Ranking Data

The engine loads Cangjie candidates from the bundled IBus Cangjie5 table, then Rime Cangjie base/extended dictionaries as fallback sources. It then loads the DATA.GOV.HK HKSCS JSON as a low-priority overlay for Hong Kong-specific characters that are missing from the base Cangjie or Sucheng sources. The IBus Cangjie5 table also provides punctuation and symbol candidates.

`third_party/ibus-table-chinese/quick-classic.txt` is bundled as `IBusTableChinese/quick-classic.txt` and is the fixed runtime source for `Sucheng` and the base order for `New Sucheng`. This table is from `ibus-table-chinese`, was converted from xcin, and its header states that it is freely redistributable without restriction. It matches the verified legacy muscle-memory anchors better than the CNS `simplecj.cin` table.

`third_party/hkscs/HKSCS2016.json` is bundled as `HKSCS/HKSCS2016.json`. It comes from DATA.GOV.HK and contains Hong Kong Supplementary Character Set code points, characters, Cangjie input codes, Cantonese pronunciation, and source references. Runtime derives Sucheng overlay codes from the official Cangjie code by taking the first and last letters. HKSCS overlay candidates are deliberately low priority, so they fill missing Hong Kong characters without moving existing fixed Sucheng first-page candidates.

`resources/sucheng_order_guards.tsv` is a small Sucheng guard file for verified anchors, such as `hi` / `竹戈` keeping `我` at position `7`, `得` at page 2 position `7`, and `等` at page 3 position `1`. The engine applies these guards first and keeps remaining Quick Classic candidates after them, so the file can be expanded incrementally without deleting fallback candidates.

`resources/sucheng_first_pages.tsv` is the Sucheng first-page golden snapshot generated by `make update-sucheng-snapshot`. It locks every populated alphabetic one/two-key Sucheng code so future changes cannot silently move candidate positions. Update it only when deliberately accepting a reviewed ranking change.

`resources/smart_phrases.tsv` contains New Sucheng phrase seeds. `Sucheng` ignores these phrase candidates so fixed Quick Classic positions are not affected. New Sucheng also uses an association-aware beam search to compose generated phrase candidates from Sucheng codes, penalizing noisy one-letter segments while still allowing useful one-letter words such as `m` -> `一`. Selected generated phrase candidates can be learned for the current session.

`resources/association_phrases.tsv` contains hand-reviewed shared association seed phrases. `Sucheng`, `New Sucheng`, `Cangjie`, and `Pinyin` all use these for post-commit associated candidates, while only `New Sucheng` learns from user selections. One phrase per line adds adjacent character associations for all Chinese modes and also lets New Sucheng auto-generate an exact phrase candidate by reverse-looking-up each character's preferred Sucheng code, for example `中文輸入法` becomes `lykjnohei`. `key<TAB>candidate1<TAB>candidate2` can add explicit association candidates without creating phrase candidates.

`resources/association_generated.tsv` is generated by `make update-association-seeds` from project-local seed TSVs, McBopomofo associated phrase data, typing corpora, IBus Cangjie5 table data, and Rime Cangjie dictionaries. Build targets convert it into `resources/association_generated.index`, a read-only sorted key index bundled for runtime lookup. It expands `Sucheng`, `New Sucheng`, `Cangjie`, and `Pinyin` post-commit association coverage without moving fixed input-code candidate positions. The engine keeps hand-reviewed seeds in memory first, then queries the generated index for the requested key, so reviewed first-page association choices stay stable while lower-priority generated suggestions fill out later pages without parsing the giant TSV on first lookup. Association lookup first checks the full committed phrase, then falls back to the last character; this lets entries such as `你 -> 好`, `可以 -> 用`, and `輸 -> 入 / 入法` work across all Chinese modes. The UI fetches up to 120 post-commit association candidates so users can page through broader related-word lists instead of only showing the first page.

`resources/pinyin_seed.tsv` is a small high-priority Traditional Chinese pinyin seed table used to keep common local ordering stable. The runtime also loads the full Rime Luna Pinyin dictionary from `RimePinyin/luna_pinyin.dict.yaml`, so pinyin mode can return broader single-character and exact phrase candidates while keeping the reviewed seed rows first.

## Local Learning Data

When using `New Sucheng`, selected existing candidates and selected association candidates can be learned locally across sessions. The ranking file is:

```text
~/Library/Application Support/PurrType/learning-rankings.json
```

The file stores a per-file salt, salted hashes, and integer scores only. It does not store learned phrase text and is not uploaded anywhere. `Sucheng` ignores this learning state and keeps fixed Quick Classic positions. `New Sucheng` applies the hashed ranking overlay at lookup time by hashing the currently visible candidate choices and matching stored scores.

Committed phrase learning keeps a short rolling local context and records phrase suffixes up to eight Chinese characters for the current session only. When the app knows the actual typed Sucheng code, that exact code is learned in memory; otherwise the engine falls back to preferred Sucheng code lookup. This lets New Sucheng surface phrases that the user actually types during the current session, without writing custom phrase text to disk or moving fixed Sucheng positions.

To clear local ranking and legacy learning files during testing:

```sh
make reset-learning
```

You can enable or disable the local learning overlay from the PurrType input menu with `Enable New Sucheng Learning`. New installs default this toggle to off. When disabled, New Sucheng keeps the base table, reviewed ordering, static phrase seeds, and generated phrase seeds, but ignores local user learning until re-enabled.

`Privacy Lock` is available from the input menu and the Preferences `Privacy` tab. When enabled, it pauses New Sucheng learning, clears the current rolling context, and hides New Sucheng association suggestions that can be affected by local learning. Fixed Sucheng, Cangjie, and Pinyin association dictionaries remain available. Turning Privacy Lock off restores the saved learning preference.

When macOS secure event input is active in terminal-style apps, such as Terminal / sudo / SSH password prompts, PurrType bypasses IME composition, hides candidates, clears rolling context, and switches to a selectable ASCII / English input source. GUI password fields depend on the host app enabling secure input correctly.

When enabled, learning is filtered before it is accepted: raw English, numbers, symbols, mixed tokens, and sensitive keywords such as password, banking, account, ID, phone, address, key, wallet, or verification-code terms are never learned. `Reset New Sucheng Learning` clears the current in-memory learning state and the hashed local ranking file.

## Current Limitations

- Sucheng uses the bundled IBus Quick Classic table as the primary fixed order, with verified legacy anchor guards layered on top. It is not a redistributed legacy dictionary file.
- New Sucheng combines static table order, verified guards, generated phrase seeds, and optional local user learning.
- New Sucheng phrase composition is seed-based, corpus-generated, association-aware code segmentation, plus optional local committed phrase learning. It is not a full language model yet.
- English pass-through uses deterministic heuristics, not a full English dictionary.
- English spelling suggestions are not implemented yet. When added, they should appear only as optional candidate rows and must not automatically replace typed English.
- Pinyin loads a full open dictionary plus local seed ranking. It supports exact pinyin syllable/phrase lookup, but it is still not a predictive language model or fuzzy-pinyin segmenter.
- The preferences UI is a helper app bundled inside the input-method app because the input method itself runs as a background app. The helper is a normal foreground app with standard app/window menu shortcuts, so it appears in Cmd+Tab while its window is open.
- English no longer has a separate selectable menu mode; automatic English detection remains conservative because Cangjie, Sucheng, and Pinyin all use overlapping letter sequences.
