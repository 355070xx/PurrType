# Manual QA

Use this checklist after `make release-preflight` and before publishing a
release candidate. Record the macOS version, CPU architecture, commit SHA,
artifact checksums, and whether the package is unsigned local, signed, or
notarized.

## Non-GUI Preflight

Run:

```sh
sh -n scripts/install-local.sh scripts/uninstall-local.sh scripts/uninstall-system.sh \
  scripts/repair-installed-input-source.sh scripts/audit-license-notices.sh \
  packaging/scripts/preinstall packaging/scripts/postinstall \
  packaging/uninstall-scripts/postinstall packaging/Uninstall-PurrType.command
make release-preflight
(cd build && shasum -a 256 -c PurrType-0.1.1-checksums.sha256)
```

For signed releases, also run:

```sh
xcrun stapler validate build/PurrType-0.1.1-signed.dmg
spctl -a -vv -t open --context context:primary-signature build/PurrType-0.1.1-signed.dmg
```

Expected result:

- tests pass
- version consistency audit passes
- Sucheng ranking audit passes
- association audit passes
- full Bible audit passes
- legacy parity audit completes and writes review queues
- license audit passes
- installer, uninstaller, repair, and audit shell scripts parse cleanly
- package smoke passes
- DMG metadata is readable

## Installer And Uninstaller

Install from the DMG:

1. Open `build/PurrType-0.1.1.dmg`.
2. Confirm only `README.txt`, `Install PurrType.pkg`, and
   `Uninstall PurrType.pkg` are present at the DMG root.
3. Double-click `Install PurrType.pkg`.
4. Complete the installer.
5. Quit and reopen System Settings if it was already open.
6. Open `System Settings > Keyboard > Text Input > Edit...`.
7. Add `PurrType`.

Expected result:

- `/Library/Input Methods/PurrTypeIM.app` exists
- System Settings shows one `PurrType` input source
- the PurrType menu switches internally between `Sucheng`, `New Sucheng`,
  `Cangjie`, and `Pinyin`
- installer registers PurrType with macOS, but does not enable or select it;
  the user adds it manually from Text Input
- an existing public install at `/Library/Input Methods/PurrTypeIM.app` remains
  present if it was installed before this test
- public package receipts and public preferences are not removed
- installer resolves the console user's home directory through macOS user
  records when removing stale local development installs, instead of assuming
  the home directory is always `/Users/<shortname>`
- stale `PurrTypeIM.localized` and `PurrTypeInput.app` installs are
  removed
- stale `/Library/Application Support/PurrType/PurrTypeIM.app` installs are
  removed

Uninstall from the DMG:

1. Double-click `Uninstall PurrType.pkg`.
2. Complete the macOS Installer flow and enter administrator credentials if prompted.
3. Quit and reopen System Settings.

Expected result:

- `/Library/Input Methods/PurrTypeIM.app` is removed
- `/Library/Application Support/PurrType/PurrTypeIM.app` is removed
- local development installs under `~/Library/Input Methods` are removed for
  the console user
- PurrType package receipts are forgotten
- user preferences and learning data are preserved
- an existing public install at `/Library/Input Methods/PurrTypeIM.app` remains
  present
- custom-home users are handled through the console user's recorded home path,
  not a hard-coded `/Users/<shortname>` path

Custom-home regression:

1. On a test account whose home directory is not under `/Users`, install a local
   development copy under that account's `Library/Input Methods`.
2. Install the package from the DMG.
3. Run `Uninstall PurrType.pkg` from the DMG.

Expected result:

- stale local development bundles are removed from the recorded home directory
- no unrelated `/Users/<shortname>` path is created
- preferences and `~/Library/Application Support/PurrType` remain

## App Matrix

Test at least these host apps:

| Host app | Focus area |
| --- | --- |
| TextEdit | normal marked text, candidate panel, row click |
| Notes | rich text insertion and candidate anchoring |
| Safari address field | URL and English pass-through |
| Safari text field | normal Chinese composition |
| Terminal | command/path English pass-through and secure input prompts |
| System Settings | input source add/select flow |

## Input Behavior

Fresh install default mode is `Sucheng`.
Use the PurrType menu, Preferences, and `Ctrl+Shift+1/2/3/4` shortcuts to
switch modes. Confirm the PurrType menu checkmark updates for each internal
mode before running the typing cases.

| Case | Action | Expected |
| --- | --- | --- |
| Sucheng fixed slot | type `hi`, press `7` | commits `我` |
| Sucheng fixed slot | type `bs`, press `6` | commits `勝` |
| Sucheng no learning | enable New Sucheng learning, learn `hi -> 我`, return to Sucheng | Sucheng fixed page order is unchanged |
| New Sucheng ranking | in New Sucheng, select `hi -> 我`, type `hi` again | `我` moves up in New Sucheng only |
| New Sucheng phrase | type `hionaomjoo`, press `1` | commits `我們是一家人` |
| New Sucheng generated phrase | type `lykjnohei`, press `1` | commits `中文輸入法` |
| Cangjie | switch to Cangjie, type `hqi`, press `1` | commits `我` |
| Cangjie | type `onf`, press `1` | commits `你` |
| Pinyin | switch to Pinyin, type `ni`, press `1` | commits `你` |
| Pinyin | type `hao`, press `1` | commits `好` |
| association | in Sucheng, New Sucheng, Cangjie, and Pinyin, commit `你` | association candidates start with `好` |
| raw English | type `setting`, press Space | commits `setting ` |
| short raw candidate | type a short token with Chinese candidates, press `0` | commits original letters |
| uppercase English | hold Shift and type `SETTING-1`, press Space | commits `SETTING-1 ` |
| paging | produce more than one page, press Space/Tab/PageDown | moves forward one page when enabled |
| reverse paging | press Shift+Tab/PageUp/Left Arrow | moves back one page |
| cancel | type letters, press Escape | clears composition and hides candidates |
| raw commit | type letters, press Enter | commits original letters |

## Preferences And Privacy

Open preferences:

```text
Ctrl+Shift+,
```

Expected result:

- Preferences window opens or refocuses
- Sidebar shows exactly Input Modes, Typing, Privacy & Learning, and About
- Preferences opens on Input Modes
- Input Modes tab switches default mode, candidate page size, and mode shortcuts
- Typing tab switches raw-English candidate and Space key behavior, and shows
  protected English as a read-only note
- Privacy & Learning tab exposes New Sucheng learning, Privacy Lock shortcut,
  Privacy Lock, and reset learning
- About tab exposes project links and version information

Privacy checks:

1. Confirm New Sucheng learning is off by default on a fresh install.
2. Enable learning, select a New Sucheng candidate, and confirm
   `~/Library/Application Support/PurrType/learning-rankings.json` exists.
3. Inspect the file and confirm it contains salt/hash/score data only, not the
   committed phrase text.
4. Turn on Privacy Lock from the menu or preferences.
5. Confirm learning status changes to paused, New Sucheng learning-ranked
   association suggestions stop appearing after commits, and Classic Sucheng
   fixed association suggestions still appear.
6. Turn Privacy Lock off and confirm the saved learning preference is restored.
7. In Terminal, trigger a secure input prompt such as `sudo -v`; confirm
   PurrType switches to an ASCII / English input source and does not show marked
   text or candidates in the password prompt. Repeat in a normal editor and
   confirm global secure input elsewhere does not immediately switch PurrType
   away.
8. Use Reset New Sucheng Learning and confirm the local ranking file is removed.

## Legal And Privacy Materials

After install, confirm these files exist in the app bundle:

```text
/Library/Input Methods/PurrTypeIM.app/Contents/Resources/Legal/LICENSE.txt
/Library/Input Methods/PurrTypeIM.app/Contents/Resources/Legal/CREDITS.md
/Library/Input Methods/PurrTypeIM.app/Contents/Resources/Legal/PRIVACY_POLICY.md
/Library/Input Methods/PurrTypeIM.app/Contents/Resources/Legal/LICENSE_AUDIT.md
/Library/Input Methods/PurrTypeIM.app/Contents/Resources/Legal/MCBOPOMOFO_LICENSE.txt
```

Also confirm runtime upstream license files exist under:

```text
/Library/Input Methods/PurrTypeIM.app/Contents/Resources/IBusTableChinese
/Library/Input Methods/PurrTypeIM.app/Contents/Resources/RimeCangjie
/Library/Input Methods/PurrTypeIM.app/Contents/Resources/RimePinyin
/Library/Input Methods/PurrTypeIM.app/Contents/Resources/HKSCS
```

## Result Template

Record:

```text
Date:
Tester:
macOS:
Hardware:
Commit:
Package:
DMG:
Signed/notarized:
Preflight result:
Installer result:
Uninstaller result:
Input behavior result:
Privacy result:
License/privacy materials result:
Issues found:
Decision:
```
