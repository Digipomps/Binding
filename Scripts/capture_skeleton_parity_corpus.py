#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors
"""Capture original public Skeleton payloads and the exact web render root.

Reads only GET routes. Does not materialize bindings, strip styles, send actions,
or load an authenticated browser's cookies. Output feeds SkeletonSnapshotRenderXCTest.
"""
import argparse
import hashlib
import http.cookiejar
import json
from pathlib import Path
import re
import shutil
import urllib.error
import urllib.request
from datetime import datetime, timezone


def expected_text(slug, aliases=False):
    return {
        "text": ["Basic structure", "public-safe", "deterministic", "Acknowledge"],
        "list": ["Alpha row", "Beta row", "Gamma row"],
        "grid": ["Card one", "Card two", "Card three"],
        "form": ["Remote parity draft", "Save draft", "Reset draft"],
        "relative-keypath": ["Relative row A", "Relative row B", "detail.a", "detail.b"],
        "markdown": ["Markdown parity", "bullet one", "bullet two"],
        "nested-reference": ["Primary workspace", "Nested title", "Nested subtitle"]
            + (["Secondary projection", "Shared row"] if aliases else []),
        "remote-bridge": ["Remote bridge contract", "Ack bridge"],
        "unavailable": ["Unavailable by design for parity.", "Toggle placeholder"],
    }.get(slug, [])


def prepare_candidate(source, output):
    """Preserve frozen HTTP bytes, using the candidate host's same-endpoint aliases.

    This is explicitly a candidate-host run, not a capture of deployed host behavior.
    Never project one cell's state into a reference with a different endpoint.
    """
    manifest = json.loads((source / "manifest.json").read_text())
    shutil.copytree(source, output)
    for fixture in manifest["fixtures"]:
        for name in fixture["scenarios"]:
            directory = output / name
            config = json.loads((directory / "configuration.json").read_text())
            state = json.loads((directory / "state.json").read_text())
            references = config.get("references", config.get("cellReferences", []))
            primary = next((r for r in references if isinstance(r.get("label"), str) and r["label"]), None)
            labels = [primary["label"]] if primary else ["conferenceUIRouter"]
            if primary and isinstance(primary.get("endpoint"), str) and primary["endpoint"]:
                labels += [r["label"] for r in references if isinstance(r.get("label"), str) and r["label"]
                           and r.get("endpoint") == primary["endpoint"]]
            root = {label: {"state": state} for label in labels}
            (directory / "root.json").write_text(json.dumps(root, indent=2, ensure_ascii=False) + "\n")
            (directory / "expected-text.json").write_text(json.dumps(expected_text(fixture["slug"], aliases=True), indent=2) + "\n")
    manifest["rootComposition"] = "Candidate host: first labeled reference and aliases with the exact same nonempty endpoint share HTTP state"
    manifest["deployedHostBehavior"] = False
    manifest["sourceManifestSHA256"] = hashlib.sha256((source / "manifest.json").read_bytes()).hexdigest()
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    print(f"Prepared candidate host root for {len(manifest['fixtures'])} frozen payloads: {output}")


def capture(base, output):
    output.mkdir(parents=True, exist_ok=False)
    client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))

    def get(route, expected=200):
        if not route.startswith(("/skeleton-parity/", "/health/")) or ".." in route:
            raise ValueError(f"Unexpected public route: {route}")
        try:
            response = client.open(base.rstrip("/") + route, timeout=20)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            body = response.read(4 * 1024 * 1024 + 1)
            if len(body) > 4 * 1024 * 1024:
                raise ValueError(f"Payload too large: {route}")
            if response.status != expected:
                raise ValueError(f"{route}: HTTP {response.status}, expected {expected}")
            return json.loads(body), body

    def write(path, value):
        path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")

    catalog, _ = get("/skeleton-parity/api/catalog")
    build, _ = get("/health/build")
    manifest = {"capturedAt": datetime.now(timezone.utc).isoformat(), "baseURL": base,
                "build": build, "styleNormalizationApplied": False, "materialized": False,
                "rootComposition": "conference-mvp.js composedRendererData: first labeled reference -> {state: HTTP state}",
                "fixtures": []}
    for fixture in catalog["fixtures"]:
        slug = fixture["slug"]
        if not re.fullmatch(r"[a-z0-9-]{1,64}", slug):
            raise ValueError(f"Invalid fixture slug: {slug}")
        if slug == "invalid":
            value, _ = get(fixture["configurationRoute"], expected=422)
            write(output / "invalid-response.json", value)
            continue
        config, raw_config = get(fixture["configurationRoute"])
        state, raw_state = get(fixture["stateRoute"])
        references = config.get("references", config.get("cellReferences", []))
        label = next((r["label"] for r in references if isinstance(r.get("label"), str) and r["label"]), "conferenceUIRouter")
        root = {label: {"state": state}}
        expected = expected_text(slug)
        entry = {"slug": slug, "configurationSHA256": hashlib.sha256(raw_config).hexdigest(),
                 "stateSHA256": hashlib.sha256(raw_state).hexdigest(), "rootLabel": label, "scenarios": []}
        for size, width, height in [("wide", 1280, 1000), ("compact", 390, 1000)]:
            name = slug + "-" + size
            directory = output / name
            directory.mkdir()
            (directory / "configuration.json").write_bytes(raw_config)
            (directory / "state.json").write_bytes(raw_state)
            write(directory / "skeleton.json", config["skeleton"])
            write(directory / "root.json", root)
            write(directory / "expected-text.json", expected)
            write(directory / "surface.json", {"padding": 16, "contentMaxWidth": 1180, "backgroundHex": "#FFFFFF"})
            write(directory / "viewport.json", {"width": width, "height": height})
            entry["scenarios"].append(name)
        manifest["fixtures"].append(entry)
    write(output / "manifest.json", manifest)
    print(f"Captured {len(manifest['fixtures'])} original fixture payloads at two widths: {output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--base-url")
    source.add_argument("--source-corpus", type=Path,
                        help="Prepare candidate same-endpoint aliases from previously frozen HTTP payloads; no network")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.source_corpus:
        prepare_candidate(args.source_corpus, args.output)
    else:
        capture(args.base_url, args.output)
