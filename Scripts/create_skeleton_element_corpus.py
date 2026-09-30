#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors
"""Create repeatable native/web inputs without stripping styles or resolving bindings.

The matrix owns its fixtures. Two supplemental fixtures come from the existing
Tree and ComponentSurface runtime oracles. Source hashes travel with every run.
An image capture is not a claim that live remote actions or all themes work.
"""

import argparse
import hashlib
import json
from pathlib import Path


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def main():
    repository = Path(__file__).resolve().parents[1]
    fixtures = repository / "BindingTests/Fixtures/SkeletonParity"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--matrix", type=Path, required=True)
    parser.add_argument("--supplemental", type=Path, default=fixtures / "supplemental-elements.json")
    parser.add_argument("--expectations", type=Path, default=fixtures / "expected-elements.json")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    cases = read(args.matrix)["cases"] + read(args.supplemental)
    expectations = read(args.expectations)
    if len({case["case"] for case in cases}) != 26 or len(cases) != 26:
        raise ValueError("Expected exactly one fixture for each of the current 26 element cases")
    if set(expectations) != {case["id"] for case in cases}:
        raise ValueError("Every fixture needs an explicit expectation, including non-text cases")
    args.output.mkdir(parents=True, exist_ok=False)
    common_root = {
        "draft": {"title": "Initial title", "body": "Initial body"},
        "rows": [{"label": "List row A"}, {"label": "List row B"}],
        "cards": [{"title": "Grid card A"}, {"title": "Grid card B"}],
        "tabs": {"active": "overview"}, "navigation": {"active": "overview"},
        "referenceRows": [{"label": "Reference row"}],
    }
    manifest = {
        "source": "CellScaffold/Tests/fixtures/SkeletonElementParityMatrix.v1.json",
        "sourceSHA256": hashlib.sha256(args.matrix.read_bytes()).hexdigest(),
        "supplementalSHA256": hashlib.sha256(args.supplemental.read_bytes()).hexdigest(),
        "styleNormalizationApplied": False, "materialized": False,
        "scope": "Standard light Porthole host; local render state, not live transport",
        "cases": [],
    }
    for case in cases:
        expected = expectations[case["id"]]
        entry = {"case": case["case"], "id": case["id"], "rasterOnly": not expected}
        if case["case"] == "ZStack":
            entry["note"] = "Canonical labels intentionally overlap; assert their common visible Layer text."
        manifest["cases"].append(entry)
        for variant, width in [("compact", 390), ("wide", 1280)]:
            directory = args.output / (case["id"] + "-" + variant)
            directory.mkdir()
            write(directory / "skeleton.json", case["fixture"])
            write(directory / "root.json", case.get("root", common_root))
            write(directory / "expected-text.json", expected)
            write(directory / "viewport.json", {"width": width, "height": 1000})
            write(directory / "surface.json", {
                "padding": 16, "contentMaxWidth": 1180, "backgroundHex": "#FFFFFF",
            })
            write(directory / "source.json", entry)
            if case["case"] == "Image":
                # Four visible quadrants in the corrected, CRC-valid 32x32 oracle.
                # This catches a blank/failed Image even when text expectations are empty.
                write(directory / "expected-raster.json", [
                    {"rgb": rgb, "tolerance": 20, "minimumPixels": 100}
                    for rgb in [[220, 40, 40], [20, 170, 70], [30, 90, 220], [245, 195, 20]]
                ])
    write(args.output / "manifest.json", manifest)
    print(json.dumps({"cases": len(cases), "scenarios": len(cases) * 2, "output": str(args.output)}))


if __name__ == "__main__":
    main()
