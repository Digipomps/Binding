#!/usr/bin/env python3
"""Declare the source/Git files read by the existing sandboxed attestation step.

Xcode treats directory inputPaths as literal paths, not recursive read grants.
Only paths are inventoried here; provenance hashes are still computed by the
original sandboxed build phase after compilation.
"""
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parent.parent
def git(*args):
    return subprocess.check_output(["git", "-C", str(root), *args])

paths = {root}
for raw in git("ls-files", "--cached", "--others", "--exclude-standard", "-z").split(b"\0"):
    if not raw:
        continue
    item = root / raw.decode()
    if not item.exists() or item.is_symlink():
        continue
    paths.add(item)
    paths.update(parent for parent in item.parents if parent == root or root in parent.parents)
for argument in ["--git-dir", "--git-common-dir"]:
    directory = pathlib.Path(git("rev-parse", "--path-format=absolute", argument).decode().strip())
    paths.add(directory)
    paths.update(item for item in directory.rglob("*") if not item.is_symlink())
if (root / ".git").is_file():
    paths.add(root / ".git")
target = root / ".binding-build" / "ProvenanceInputs.xcfilelist"
target.parent.mkdir(exist_ok=True)
lines = []
for item in sorted(paths):
    value = str(item)
    if any(c in value for c in "\n\r\t") or "$" in value:
        raise SystemExit("Unsupported control character or macro in an attestation input path")
    lines.append(value)
target.write_text("\n".join(lines) + "\n")
print(f"Declared {len(lines)} provenance inputs; source hashing remains in the sandboxed build phase.")
