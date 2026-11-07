#!/usr/bin/env python3
"""Exercise installer scripts against temporary paths; mock macOS registration only.

This verifies file lifecycle and data preservation, not macOS Installer or TIS GUI.
No installed input method is modified or launched.
"""
import os
from pathlib import Path
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]


def main():
    with tempfile.TemporaryDirectory(prefix="purrtype-package-lifecycle-") as scratch:
        root = Path(scratch)
        tools = root / "tools"
        tools.mkdir()
        user_home = root / "CustomHome/purrtest"
        user_home.mkdir(parents=True)
        log = root / "commands.log"
        env = dict(os.environ, PURRTYPE_HELPER_LOG=str(log))
        stubs = {
            "stat": 'case "$2" in %Su) echo purrtest;; %u) echo 501;; *) exit 1;; esac',
            "dscl": f"printf '%s\\n' 'NFSHomeDirectory: {user_home}'",
            "pkgutil": 'printf "pkgutil %s\\n" "$*" >> "$PURRTYPE_HELPER_LOG"',
            "pkill": 'printf "pkill %s\\n" "$*" >> "$PURRTYPE_HELPER_LOG"',
            "launchctl": 'printf "launchctl %s\\n" "$*" >> "$PURRTYPE_HELPER_LOG"',
            "lsregister": 'printf "lsregister %s\\n" "$*" >> "$PURRTYPE_HELPER_LOG"',
            "sw_vers": 'echo "${PURRTYPE_TEST_MACOS_VERSION:-12.0}"',
        }
        for name, body in stubs.items():
            path = tools / name
            path.write_text("#!/bin/sh\n" + body + "\n")
            path.chmod(0o755)

        def run(relative, expect_success=True):
            source = (REPO / relative).read_text()
            source = source.replace("PATH=/usr/bin:/bin:/usr/sbin:/sbin", f"PATH={tools}:/usr/bin:/bin:/usr/sbin:/sbin")
            source = source.replace('"/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"', f'"{tools}/lsregister"')
            source = source.replace('"/Library/', f'"{root}/Library/')
            source = source.replace('"/Users/', f'"{root}/Users/')
            source = source.replace('/usr/bin/sw_vers', str(tools / 'sw_vers'))
            script = root / (relative.replace("/", "_") + ".sh")
            script.write_text(source)
            result = subprocess.run(["/bin/sh", str(script)], env=env, timeout=40)
            assert (result.returncode == 0) == expect_success, (relative, result.returncode)

        def app(path, version):
            binary = path / "Contents/MacOS/PurrType"
            binary.parent.mkdir(parents=True, exist_ok=True)
            binary.write_text('#!/bin/sh\nprintf "helper %s\\n" "$*" >> "$PURRTYPE_HELPER_LOG"\n')
            binary.chmod(0o755)
            (path / "version.txt").write_text(version)

        system_app = root / "Library/Input Methods/PurrTypeIM.app"
        local_app = user_home / "Library/Input Methods/PurrTypeIM.app"
        legacy = root / "Library/Application Support/PurrType/PurrTypeIM.app"
        fixtures = {
            user_home / "Library/Application Support/PurrType/learning-rankings.json": b'{"fixture":"learning"}',
            user_home / "Library/Application Support/PurrType/quick-phrases.json": b'{"fixture":"phrases"}',
            user_home / "Library/Preferences/org.purrtype.inputmethod.PurrTypeUnified.plist": b"preference-fixture",
        }
        for path, data in fixtures.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)

        def preserved():
            for path, data in fixtures.items():
                assert path.read_bytes() == data, f"user data changed: {path}"

        # Upgrade from 0.1.5, including a duplicate user-level and misplaced copy.
        for path in [system_app, local_app, legacy]:
            app(path, "0.1.5")
        env['PURRTYPE_TEST_MACOS_VERSION'] = '11.7.10'
        run("packaging/scripts/preinstall", expect_success=False)
        assert all(path.exists() for path in [system_app, local_app, legacy])
        assert not log.exists(), "unsupported OS must be rejected before cleanup"
        preserved()
        env['PURRTYPE_TEST_MACOS_VERSION'] = '12.0'
        run("packaging/scripts/preinstall")
        assert not any(path.exists() for path in [system_app, local_app, legacy])
        preserved()
        app(system_app, "0.1.6")  # Installer payload delivery is mocked, never run.
        run("packaging/scripts/postinstall")
        assert (system_app / "version.txt").read_text() == "0.1.6"
        preserved()

        # Reinstall the same version, then remove it twice (idempotent cleanup).
        run("packaging/scripts/preinstall")
        app(system_app, "0.1.6")
        run("packaging/scripts/postinstall")
        preserved()
        run("packaging/uninstall-scripts/postinstall")
        assert not system_app.exists()
        preserved()
        run("packaging/uninstall-scripts/postinstall")
        preserved()

        # Clean install after removal.
        run("packaging/scripts/preinstall")
        app(system_app, "0.1.6")
        run("packaging/scripts/postinstall")
        preserved()
        commands = log.read_text()
        assert "helper --register-input-source" in commands
        assert "helper --disable-input-source" in commands
        assert "pkgutil --forget org.purrtype.inputmethod.PurrTypeUnified.pkg" in commands
        assert "--enable-input-source" not in commands
        print("PASS: unsupported OS rejected before cleanup; simulated upgrade, reinstall, clean install and repeated uninstall; custom-home data preserved")
        print("SCOPE: registration, process control, package receipts and payload delivery mocked; not an installed GUI test")


if __name__ == "__main__":
    main()
