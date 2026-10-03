"""Freeze current tracked sources + active untracked source/resource files.

Never modifies original repositories. The manifest records source bytes before
test-harness changes; diffable snapshot branches retain the parent commits.
"""
import hashlib
import json
import pathlib
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent
PARENT = ROOT.parents[2]
def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args])

manifest = {}
for name in ['Binding', 'CellProtocol']:
    source = PARENT / name
    target = ROOT / name
    assert not target.exists(), target
    head = git(source, 'rev-parse', 'HEAD').decode().strip()
    subprocess.run(['git', 'clone', '--shared', '--no-checkout', str(source), str(target)], check=True)
    git(target, 'checkout', '-b', 'codex/parity-night-20260914', head)
    tracked = git(source, 'ls-files', '-z').decode().split('\0')
    extras = git(source, 'ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')
    roots = {'Binding', 'BindingTests', 'BindingUITests', 'Cells', 'Sources', 'Tests', 'Resources'}
    selected = [p for p in extras if p and pathlib.PurePath(p).parts[0] in roots]
    files = {}
    for relative in sorted(set(tracked + selected) - {''}):
        src, dst = source / relative, target / relative
        if src.is_file():
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            files[relative] = hashlib.sha256(src.read_bytes()).hexdigest()
        elif not src.exists() and dst.is_file():
            dst.unlink()
            files[relative] = 'deleted'
    manifest[name] = dict(source=str(source), head=head, addedSourceFiles=selected, files=files)
    print(name, head, len(files), 'files;', len(selected), 'untracked source/resources retained')
(ROOT / 'source-manifest.json').write_text(json.dumps(manifest, indent=2))
