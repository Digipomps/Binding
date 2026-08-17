# Guarded Binding staging build

`Scripts/build_binding_staging_candidate.sh` is the single supported local
workflow for an installable DeviceIngress staging candidate. It fails closed
unless the Binding source tree is clean, package resolution stays locked, both
the `40 GiB` and `4%` free-space gates pass, and the finished app is signed and
attested to the exact source revision.

The workflow owns only this DerivedData root:

`/private/tmp/haven-xcode-derived/Binding-DeviceIngress-Staging`

The first use of a pre-existing Xcode-created root requires the explicit
`--adopt-existing-root` option. Adoption is limited to known Xcode top-level
children and refuses roots larger than 32 GiB. Later builds require the
ownership marker. A per-build lease prevents concurrent writers; a stale lease
is reported with its age and is never removed automatically.

Run from a clean checkout:

```sh
Scripts/build_binding_staging_candidate.sh --adopt-existing-root
```

Use `--preflight-only` to exercise the capacity, ownership and lease gates
without invoking Xcode.

The script intentionally does not delete caches. If a disk gate fails, first
run the metadata-only inventory from the `haven-disk-and-machine-health` skill.
Any cleanup must then use that skill's `cleanup_guard.py`, an exact allowlisted
child of the marked root, minimum age and size bounds, no active lease, and the
human approval token printed by the plan step. SourcePackages, source trees,
worktrees and unclassified data are never implicit cleanup targets.

Debug candidates install as **HAVEN Staging** while retaining the production
bundle identity required for DeviceIngress. Release builds remain **HAVEN**.
This makes the candidate visually distinguishable from retained playground or
older development apps without uninstalling them or changing production
metadata.
