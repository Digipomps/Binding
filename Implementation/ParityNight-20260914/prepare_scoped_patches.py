"""Export only reviewed parity changes against the preserved pre-night sources."""
from pathlib import Path
import difflib
import hashlib
import json
import subprocess

root = Path(__file__).resolve().parent
manifest = json.loads((root / "source-manifest.json").read_text())
files = {
    "Binding": [
        "Binding/SkeletonPresentationOverlayView.swift",
        "Binding/FullLibraryView.swift",
        "BindingTests/ParityNightRegressionTests.swift",
    ],
    "CellProtocol": [
        "Sources/CellApple/Cells/Porthole/Utility Views/CellGridView.swift",
        "Sources/CellApple/Cells/Porthole/Utility Views/Skeleton/Suggestion/SkeletonView.swift",
    ],
}
checks = []
for repo, paths in files.items():
    chunks = []
    for relative in paths:
        before = root / "before-source" / repo / relative
        current = root / repo / relative
        if before.exists():
            assert hashlib.sha256(before.read_bytes()).hexdigest() == manifest[repo]["files"][relative]
            old, source_label = before.read_text().splitlines(keepends=True), "a/" + relative
        else:
            assert relative == "BindingTests/ParityNightRegressionTests.swift"
            old, source_label = [], "/dev/null"
        chunks.extend(difflib.unified_diff(old, current.read_text().splitlines(keepends=True),
                                         fromfile=source_label, tofile="b/" + relative))
    patch = root / (repo + "-renderer-fixes.patch")
    patch.write_text("".join(chunks))
    checked = subprocess.run(["git", "apply", "--check", "--whitespace=error", str(patch)],
                             cwd=manifest[repo]["source"], text=True, capture_output=True)
    checks.append({"repo": repo, "paths": paths, "patch": patch.name,
                   "sha256": hashlib.sha256(patch.read_bytes()).hexdigest(),
                   "applyCheckExitCode": checked.returncode, "output": checked.stdout + checked.stderr})

changes = []
for repo, info in manifest.items():
    for relative, expected in info.get("files", {}).items():
        original = Path(info["source"]) / relative
        actual = hashlib.sha256(original.read_bytes()).hexdigest() if original.is_file() else None
        if actual != expected:
            changes.append({"repo": repo, "path": relative, "expected": expected, "actual": actual})
(root / "phase3-patch-checks.json").write_text(json.dumps(checks, indent=2) + "\n")
(root / "phase3-original-source-change-check.json").write_text(json.dumps(changes, indent=2) + "\n")
print(json.dumps({"patchChecks": checks, "originalSourceChanges": changes}, indent=2))
assert all(item["applyCheckExitCode"] == 0 for item in checks)
assert not changes
