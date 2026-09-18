#!/usr/bin/env python3
"""Make a disposable macOS person-link UI fixture visibly and operationally distinct.

Only the exact isolated test bundle ID under the system temporary directory is
accepted. No user containers, identity stores, installed phone apps, or normal
HAVEN builds are modified. Run after copying/re-identifying the test bundle and
before launching it. --apply is required for mutation; default only checks.
"""
import argparse
from pathlib import Path
import plistlib
import subprocess
import tempfile

FIXTURE_ID = 'org.digipomps.haven.person-link-ui-test'
LABEL = 'HAVEN UI-test'
LSREGISTER = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'


def isolated_metadata(original):
    if original.get('CFBundleIdentifier') != FIXTURE_ID:
        raise ValueError('Refusing to change a bundle other than the isolated person-link UI fixture')
    result = dict(original)
    result['CFBundleName'] = LABEL
    result['CFBundleDisplayName'] = LABEL
    result['HAVENUIFixture'] = True
    result.pop('CFBundleURLTypes', None)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    app = args.app.resolve(strict=True)
    temporary_roots = (Path('/private/tmp'), Path(tempfile.gettempdir()).resolve())
    if app.suffix != '.app' or not any(app.is_relative_to(root) for root in temporary_roots):
        parser.error('Only a disposable .app below a system temporary directory is accepted')
    info = app / 'Contents/Info.plist'
    original = plistlib.loads(info.read_bytes())
    expected = isolated_metadata(original)
    if not args.apply:
        if original != expected:
            parser.exit(1, 'Fixture is not isolated: name or URL handlers need correction\n')
        print('PASS: HAVEN UI-test; no registered URL types in bundle metadata')
        return
    executable = app / 'Contents/MacOS' / original['CFBundleExecutable']
    processes = subprocess.check_output(['/bin/ps', '-axo', 'comm='], text=True)
    if str(executable) in [line.strip() for line in processes.splitlines()]:
        parser.error('Close the fixture normally before changing its bundle')
    # Preserve the original metadata for review/rollback outside the bundle.
    backup = app.parent / (app.name + '.before-ui-isolation.plist')
    if not backup.exists():
        backup.write_bytes(info.read_bytes())
    subprocess.run([LSREGISTER, '-u', str(app)], check=True)
    info.write_bytes(plistlib.dumps(expected))
    subprocess.run(['/usr/bin/codesign', '--force', '--sign', '-',
                    '--preserve-metadata=identifier,entitlements,flags', str(app)], check=True)
    subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    print('PASS: fixture renamed, URL handlers removed, old registration withdrawn, ad-hoc signature verified')


if __name__ == '__main__':
    main()
