# PurrType 0.1.6 verification record

This record distinguishes build checks, translated execution, CI and physical Mac acceptance.

## Build and compatibility scope

- Local host: Apple Silicon (`arm64`), macOS 26.6.2; Apple Clang 17, macOS SDK 26.1.
- Input method and embedded Preferences app: successfully compiled and linked with
  both `arm64` and `x86_64`; each slice targets macOS 12.0, bundle version 106.
- Bundle and extracted PKG checks verify both architectures, deployment target,
  version, system-only dependencies and code-signature integrity.
- Negative release guards reject a validly re-signed thin main executable,
  a validly re-signed thin Preferences helper, and incorrect minimum OS metadata.
- Final local `make release-preflight` completed successfully (exit 0).
- All 13 native test/benchmark executables passed, including typing simulation,
  Preferences UI, bundle contracts and mocked Speech controller behavior.
- Native Sucheng ranking, associations, full Bible typing, legacy parity and
  license audits passed.
- Unsupported macOS (<12) is rejected before installer cleanup; verified with
  a simulated macOS 11 environment.
- Isolated script lifecycle tests passed: previous-version replacement, stale
  user-level copy cleanup, same-version reinstall, repeated uninstall, clean
  install and custom-home preservation of preferences, Quick Phrases and learning.
  Process control, TIS/LaunchServices registration, receipts and payload delivery
  are mocked. These are not live Installer tests.
- Rosetta x86_64: all 13 test/benchmark executables and the Sucheng ranking,
  association and full Bible typing audits passed. Test files were verified as
  x86_64-only executables running on the Apple Silicon host; this is not Intel hardware.
- GitHub ARM and Intel CI: results available on the release commit's Actions page;
  CI is automated runner evidence, not physical Intel GUI/audio certification.

## Signing

The app is ad-hoc signed; the PKG/DMG are not Developer ID signed or notarized,
as with the preceding public distribution. Gatekeeper may require the documented
Privacy & Security > Open Anyway flow. Valid signature integrity does not mean
Apple notarization or Gatekeeper acceptance.

The optional signed workflow now checks credentials before building and checks
Gatekeeper acceptance after notarization, not before it. The missing-identity
failure path and workflow ordering were checked. End-to-end Developer ID signing
and notarization were not tested because no identities are available on this host.

## Acceptance still pending

- Physical Intel Mac installation, real application typing, logout/login and removal.
- Runtime on macOS 12 Monterey (both architectures) and macOS 13.
- Real Cantonese microphone recognition, offline behavior, permissions and custom
  language-model preparation on Intel / older macOS. macOS 12/13 skip the custom
  model; Apple Speech availability can depend on locale and network.
- Live upgrade/removal on a clean test user or test machine. The user's installed
  input method was not replaced to perform these checks.

Do not interpret compilation, Rosetta or CI as proof that these pending scenarios passed.
