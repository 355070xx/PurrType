# Changelog

## 0.1.2

- Adds free Quick Phrases: user-defined `;` short codes such as `;email` can expand to saved replacement text from local storage.
- Adds free Quick Phrases TXT import/export and basic backup/restore for local Quick Phrases data.

## 0.1.1

- Adds local English spelling suggestions using macOS `NSSpellChecker`, shown only as optional candidates without autocorrect or online lookup; suggestions can appear in raw English and mixed Chinese candidate pages.
- Refreshes Pinyin candidate handling so Up/Down changes the highlighted candidate and Space commits that highlighted candidate.

## 0.1.0

Initial public release candidate.

- Provides one macOS-visible `PurrType` input source with internal `Sucheng`, `New Sucheng`, `Cangjie`, and `Pinyin` modes.
- Keeps Classic Sucheng candidate positions fixed while New Sucheng can use opt-in local ranking and session-only phrase learning.
- Handles raw English pass-through for URLs, email addresses, paths, code-like tokens, long English words, and uppercase Shift typing.
- Builds Quick Classic, Cangjie5, Rime Cangjie, Rime Pinyin, and generated association data into read-only runtime indexes.
- Includes candidate paging, row click selection, configurable 5- or 9-candidate pages, mode shortcuts, Preferences, Privacy Lock, and reset learning controls.
- Uses local-only processing and stores New Sucheng persistent ranking as salted hashes and scores rather than learned plaintext phrases.
- Ships package, DMG, uninstall package, privacy policy, credits, license audit, and manual QA documentation.
