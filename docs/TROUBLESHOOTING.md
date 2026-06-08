# Troubleshooting

This page covers user-visible install, input-source, and diagnostic checks for PurrType. Current selectable modes are `Sucheng`, `New Sucheng`, `Cangjie`, and `Pinyin`; English is handled by automatic raw English pass-through. Do not paste passwords, private keys, authorization tokens, banking details, IDs, addresses, or other sensitive text into bug reports. Mask sensitive values as `***`.

## PurrType Does Not Appear

1. Quit and reopen System Settings.
2. Open `System Settings > Keyboard > Text Input > Edit...`.
3. Look for one input source named `PurrType`.
4. Log out and back in if the input source list still shows stale results.

Developer checks:

```sh
make tis-probe TIS_ID=org.purrtype.inputmethod.PurrTypeUnified
make tis-inspect
```

Expected output includes:

```text
id=org.purrtype.inputmethod.PurrTypeUnified name=PurrType
count=1
```

If the input source exists but is not enabled:

```sh
make enable
make select
```

## PurrType Is Grey In Text Fields

If `PurrType` appears in the input menu but becomes grey only after a text
field receives focus, first verify the Text Input Sources state:

```sh
make tis-inspect
```

Expected output includes:

```text
id=org.purrtype.inputmethod.PurrTypeUnified
category=TISCategoryKeyboardInputSource
type=TISTypeKeyboardInputMethodWithoutModes
enabled=true
```

If `enabled` is not `true`, or the input menu still shows stale state after an
upgrade, re-enable the current user's source and refresh the menu agent:

```sh
make enable
pkill -x TextInputMenuAgent
```

For package installs without the source tree, run the installed helper directly:

```sh
"/Library/Input Methods/PurrTypeIM.app/Contents/MacOS/PurrType" --enable-input-source
pkill -x TextInputMenuAgent
```

If the machine previously installed a build that exposed `PurrType - Sucheng`,
`PurrType - New Sucheng`, `PurrType - Cangjie`, or `PurrType - Pinyin` as
separate macOS input sources, run the migration repair after installing the
latest package:

```sh
make repair-input-source
```

To also select PurrType immediately after repair:

```sh
make repair-input-source-select
```

If this happens only in specific Apple dialogs on macOS 26.x, also test with
`System Settings > Keyboard > Text Input > Automatically switch to a document's
input source` turned off. macOS 26.x has shipped input focus regressions where
the active text field can reject menu-bar input source switching even when TIS
reports the source as enabled and selectable.

PurrType should appear as one macOS input source. If System Settings shows
multiple grey `PurrType - ...` rows, the installed package exposed internal
modes as separate input sources and should be replaced by a build without
`ComponentInputModeDict`. Also check for an invalid system location:

```sh
ls -ld "/Library/Application Support/PurrType/PurrTypeIM.app"
```

PurrType must live under `/Library/Input Methods/PurrTypeIM.app`. Current
installers and uninstallers remove the invalid Application Support bundle.

Also check whether LaunchServices has seen development or expanded-package
copies with the same bundle identifier. Those copies are not valid input method
install locations and can confuse the menu cache:

```sh
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -dump | grep -F "org.purrtype.inputmethod.PurrTypeUnified" -B 8
```

The valid installed path should be:

```text
/Library/Input Methods/PurrTypeIM.app
```

Development copies under `build/`, `build/pkgroot/`, or
`build/package-smoke/expanded/` must not remain registered. Current build and
package targets unregister those paths automatically; if diagnosing an older
tree, unregister the stale copies before refreshing the menu agent:

```sh
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -u "$PWD/build/PurrTypeIM.app"
"$LSREGISTER" -u "$PWD/build/pkgroot/Library/Input Methods/PurrTypeIM.app"
"$LSREGISTER" -u "$PWD/build/package-smoke/expanded/Payload/Library/Input Methods/PurrTypeIM.app"
"$LSREGISTER" -gc
pkill -x TextInputMenuAgent
```

## Stop A Stuck Input Method

```sh
make stop
```

If needed, use Activity Monitor and search for:

```text
PurrType
```

## Reset Local Learning

This removes only PurrType local learning files:

```sh
make reset-learning
```

New Sucheng committed custom phrases are session-only and disappear after the input method process restarts.

## Voice Input (Beta) Does Not Start

Voice Input is a beta feature. It is optional and starts only from `Option+Z`, the PurrType
menu, or the floating voice button. It is blocked when Privacy Lock is on or
when macOS secure event input is active.

Check macOS permissions:

```text
System Settings > Privacy & Security > Microphone
System Settings > Privacy & Security > Speech Recognition
```

Ensure PurrType is allowed in both places, then stop and restart the input
method if macOS does not apply the permission immediately:

```sh
make stop
```

Select PurrType again from the macOS input menu and retry `Option+Z`.

## Collect Non-Sensitive Diagnostics

Capture recent process logs:

```sh
log show --last 15m --predicate 'process == "PurrType" OR process == "PurrTypePreferences"' --style compact
```

Check recent crash reports:

```sh
ls -lt ~/Library/Logs/DiagnosticReports/PurrType*.crash ~/Library/Logs/DiagnosticReports/PurrTypePreferences*.crash 2>/dev/null | head
```

Check the installed bundle:

```sh
codesign --verify --deep --strict --verbose=2 "$HOME/Library/Input Methods/PurrTypeIM.app"
plutil -p "$HOME/Library/Input Methods/PurrTypeIM.app/Contents/Info.plist"
```

For system-level package installs, replace the path with:

```text
/Library/Input Methods/PurrTypeIM.app
```

## Manual Smoke Test Matrix

After selecting `PurrType`, test:

- TextEdit: Sucheng `hi` then `7` commits `我`.
- Safari address field: `https://example.com` stays raw English.
- Notes: `Ctrl+Shift+2`, then New Sucheng `hionaomjoo` then `1` commits `我們是一家人`.
- Terminal: shell-like tokens such as `foo_bar` and `./path` stay raw English.
- System Settings: one `PurrType` input source appears under Text Input; the PurrType menu switches internal modes.
- Pinyin: `ni` then `1` commits a Traditional Chinese candidate such as `你`.
- English: misspelled words are not auto-corrected; spelling suggestions only appear as optional candidates when enabled.
- Voice Input: `Option+Z` starts Cantonese dictation in a normal text field and a second `Option+Z` commits or stops it.

## Release Artifact Checks

Unsigned local artifacts:

```sh
make release-artifacts
(cd build && shasum -a 256 -c PurrType-0.1.3-checksums.sha256)
```

Source-first GitHub releases do not require Developer ID signing. Signed and notarized prebuilt binary artifacts require Developer ID identities and a notarytool keychain profile:

```sh
make release-signed \
  DEVELOPER_ID_APPLICATION_IDENTITY="Developer ID Application: Example (TEAMID)" \
  DEVELOPER_ID_INSTALLER_IDENTITY="Developer ID Installer: Example (TEAMID)" \
  NOTARY_KEYCHAIN_PROFILE="PurrTypeNotary"
```

Verify the stapled signed DMG:

```sh
xcrun stapler validate build/PurrType-0.1.3-signed.dmg
spctl -a -vv -t open --context context:primary-signature build/PurrType-0.1.3-signed.dmg
```
