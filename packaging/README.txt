PurrType 0.1.6
============

Official release:
https://github.com/355070xx/PurrType/releases/tag/v0.1.6

Direct DMG download:
https://github.com/355070xx/PurrType/releases/download/v0.1.6/PurrType-0.1.6.dmg

Compatibility:

This universal package includes native Intel (x86_64) and Apple Silicon (arm64)
executables. Minimum deployment target: macOS 12 Monterey. Intel hardware and
macOS 12 runtime acceptance remain pending; see the release test report.
Speech Beta availability depends on macOS, locale, network and Apple Speech.

Install:

1. Double-click Install PurrType.pkg.
2. Complete the macOS Installer flow.
3. Quit and reopen System Settings if it was already open.
4. Open System Settings > Keyboard > Text Input > Edit...
5. Add input source: PurrType.

On macOS 12 Monterey, use System Preferences > Keyboard > Input Sources > +
to add PurrType instead of the newer System Settings path.

No Terminal commands are required to install from this DMG.

If macOS says "Install PurrType.pkg" Not Opened or "Apple could not verify",
click Done. Do not click Move to Bin. Then open Install Guide.html in this DMG
and follow the pictures. The guide includes Traditional Chinese and English
tabs.

To remove PurrType:

1. Double-click Uninstall PurrType.pkg.
2. Complete the macOS Installer flow.
3. Quit and reopen System Settings.

The uninstaller removes only PurrType app bundles and package receipts. It
preserves local PurrType preferences and New Sucheng learning data.

After selecting PurrType from the macOS input menu, the default mode is Sucheng.
Use the PurrType menu, mode shortcuts, or PurrType Preferences to switch between
Sucheng, New Sucheng, Cangjie, and Pinyin.

Voice Input is a beta testing feature. It starts only when you trigger it, uses
Apple Speech and the microphone permission, and does not store audio or voice
transcripts.

Candidate keys:

- Number keys select visible Chinese candidates.
- 0 commits the typed letters unchanged when a short English token also has
  Chinese candidates.
- Space, Tab, Right Arrow, or PageDown moves to the next candidate page.
- Left Arrow, Shift+Tab, or PageUp moves to the previous candidate page.
- Hold Shift while typing letters for uppercase English.
- Ctrl+Shift+, opens or refocuses PurrType Preferences.

The installer places PurrType at:

/Library/Input Methods/PurrTypeIM.app

It registers PurrType with macOS, but does not enable or select it for the
console user. Add PurrType manually from System Settings > Keyboard > Text Input.

If PurrType does not appear immediately:

1. Quit and reopen System Settings.
2. Log out and log back in.
3. Check System Settings > Keyboard > Text Input again.

License, acknowledgement, and privacy materials are included inside the installed
app bundle under Contents/Resources/Legal, and are also available in the source
repository.
