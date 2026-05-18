# PurrType Privacy Policy

Effective date: May 15, 2026

PurrType is a local-first macOS input method. Its privacy model is simple:
typing, candidate lookup, ranking, association suggestions, preferences, and
New Sucheng learning are designed to run on the user's Mac.

## Scope

This policy covers the open-source PurrType input method bundle,
`PurrTypePreferences.app`, the packaged installer and uninstaller scripts, the
release DMG materials, and the bundled runtime dictionary/table data in this
repository.

It does not cover third-party websites, GitHub issue comments, email, payment
processors, or future services that are not part of this local app.

## Network Access

PurrType does not require network access for:

- Chinese candidate lookup
- English pass-through handling
- association candidates
- New Sucheng local ranking
- Privacy Lock
- preferences

The current app does not implement telemetry, analytics, cloud sync, remote
spell checking, remote AI suggestions, ads, or account login.

The installer and uninstaller do not contact remote services. They use local
macOS tools to copy or remove PurrType app bundles, register or unregister the
input source, refresh Launch Services where available, and forget PurrType
package receipts.

## Data Processed Locally

While the input method is active, PurrType processes the keystrokes and
composition text needed to produce candidates and commit text into the frontmost
app. This processing happens in memory and uses bundled local resources:

- IBus Cangjie5 and Quick Classic / Sucheng tables
- Rime Cangjie and Luna Pinyin dictionary data
- McBopomofo associated phrase data-derived association seeds
- DATA.GOV.HK HKSCS overlay data
- project-local phrase, association, pinyin seed, and compatibility tables

PurrType does not ask for Accessibility permission to inspect the current app,
browser DOM, web forms, or password fields.

## Data Stored On Disk

PurrType stores only app settings and optional local learning state.

Preferences are stored through macOS user defaults under:

```text
org.purrtype.inputmethod.PurrTypeUnified
```

These preferences can include the selected internal mode, page size, shortcut
choices, language preference, raw-English candidate preference, Space paging
preference, Privacy Lock state, and whether New Sucheng learning is enabled.
`PurrTypePreferences.app` uses the same defaults suite so the input method and
preferences window see one shared settings state.

If the user enables New Sucheng learning, PurrType may store local ranking data
at:

```text
~/Library/Application Support/PurrType/learning-rankings.json
```

That file stores a per-file salt, salted hashes, and integer scores. It is
written as compact JSON with atomic file writes. It does not store readable
learned phrases, raw English, passwords, or original input text.

Committed custom phrase learning is session-only. It is kept in memory and is
not written to disk.

The macOS Installer may create or update local package receipts under macOS'
standard receipt database. These receipts identify installed package IDs and are
not PurrType typing data.

## Sensitive Input Handling

New Sucheng learning is off by default and must be enabled by the user.

Even when learning is enabled, PurrType rejects learning for raw English,
numbers, symbols, mixed tokens, and sensitive-looking text such as password,
banking, account, ID, phone, address, private key, wallet, and verification-code
terms.

Privacy Lock is available from the input menu and Preferences. When enabled, it:

- pauses New Sucheng learning
- clears rolling context
- hides New Sucheng association suggestions that can be affected by local learning
- keeps fixed Sucheng, Cangjie, and Pinyin association dictionaries available

When macOS secure event input is active in terminal-style apps, such as
Terminal password prompts, PurrType bypasses IME composition and candidate UI,
clears rolling context, and switches to a selectable ASCII / English input
source. Standard GUI password fields still depend on the host app enabling
secure input correctly.

## Logs And Reports

PurrType should not log full user input, passwords, tokens, private keys,
authorization material, banking details, IDs, addresses, or other sensitive
text.

When reporting bugs, do not attach raw sensitive input or private documents.
Mask sensitive values as:

```text
***
```

## User Controls

Clear New Sucheng local learning:

```sh
make reset-learning
```

Remove a system install:

```sh
make uninstall-system
```

Remove a local development install:

```sh
make uninstall-local
```

The release DMG also includes `Uninstall PurrType.pkg`. It removes PurrType app
bundles and package receipts. It preserves local PurrType preferences and
learning data.

By default, uninstall paths remove PurrType app bundles, stale legacy app
bundles, Launch Services registrations, and package receipts only. User
preferences and New Sucheng learning data are preserved unless the user
intentionally runs the source-tree purge command:

```sh
packaging/Uninstall-PurrType.command --purge-user-data
```

Manual deletion paths for local data are:

```text
~/Library/Application Support/PurrType
~/Library/Preferences/org.purrtype.inputmethod.PurrTypeUnified.plist
```

## Future Features

Future English spelling suggestions must remain local-only candidate
suggestions. They must not autocorrect, secretly replace typed English, or send
typed text to a remote service.

Cloud sync, remote AI suggestion, and account-based telemetry are out of scope
for the core input method.
