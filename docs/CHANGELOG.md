# Changelog

## 0.1.0

Initial public release candidate.

- Provides one macOS-visible `PurrType` input source with internal `Sucheng`, `New Sucheng`, `Cangjie`, and `Pinyin` modes.
- Keeps Classic Sucheng candidate positions fixed while New Sucheng can use opt-in local ranking and session-only phrase learning.
- Handles raw English pass-through for URLs, email addresses, paths, code-like tokens, long English words, and temporary Shift typing.
- Builds Quick Classic, Cangjie5, Rime Cangjie, Rime Pinyin, and generated association data into read-only runtime indexes.
- Includes candidate paging, row click selection, configurable 5- or 9-candidate pages, mode shortcuts, Preferences, Privacy Lock, and reset learning controls.
- Uses local-only processing and stores New Sucheng persistent ranking as salted hashes and scores rather than learned plaintext phrases.
- Ships package, DMG, uninstall package, privacy policy, credits, license audit, and manual QA documentation.
