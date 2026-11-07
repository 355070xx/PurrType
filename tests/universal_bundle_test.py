#!/usr/bin/env python3
"""Prove that release validation rejects incomplete or mismatched app bundles."""
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile

source = Path(sys.argv[1]).resolve()
repo = Path(__file__).resolve().parents[1]
info = plistlib.loads((source / "Contents/Info.plist").read_bytes())
arguments = [info[key] for key in ("LSMinimumSystemVersion", "CFBundleShortVersionString", "CFBundleVersion")]

with tempfile.TemporaryDirectory(prefix="purrtype-universal-guards-") as scratch:
    for name, relative, expected in [
        ("thin-input-method", "Contents/MacOS/PurrType", "expected arm64 and x86_64"),
        ("thin-preferences", "Contents/Resources/PurrTypePreferences.app/Contents/MacOS/PurrTypePreferences", "expected arm64 and x86_64"),
        ("wrong-minimum", "Contents/Info.plist", "LSMinimumSystemVersion="),
    ]:
        bundle = Path(scratch) / name / "PurrTypeIM.app"
        shutil.copytree(source, bundle, symlinks=True)
        target = bundle / relative
        if name.startswith("thin-"):
            thin = target.with_suffix(".thin")
            subprocess.run(["lipo", str(target), "-thin", "arm64", "-output", str(thin)], check=True)
            thin.replace(target)
            # A valid signature must not let a single-architecture helper pass.
            subprocess.run(["codesign", "--force", "--sign", "-", str(bundle / "Contents/Resources/PurrTypePreferences.app")], check=True, capture_output=True)
            subprocess.run(["codesign", "--force", "--sign", "-", str(bundle)], check=True, capture_output=True)
        else:
            subprocess.run(["/usr/libexec/PlistBuddy", "-c", "Set :LSMinimumSystemVersion 13.0", str(target)], check=True)
        result = subprocess.run(["ruby", str(repo / "scripts/verify-universal-bundle.rb"), str(bundle), *arguments], capture_output=True, text=True)
        assert result.returncode != 0 and expected in result.stderr, (name, result.stdout, result.stderr)
        print(f"PASS: release guard rejected {name}")
