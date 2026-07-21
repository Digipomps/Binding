#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT = REPO_ROOT / "Scripts" / "apple_release_m0_preflight.py"
WRAPPER = REPO_ROOT / "Scripts" / "apple_release_m0_preflight.sh"
FIXTURES = REPO_ROOT / "Tests" / "fixtures" / "apple_release_m0_preflight"

MODULE_SPEC = importlib.util.spec_from_file_location("apple_release_m0_preflight", SCRIPT)
if MODULE_SPEC is None or MODULE_SPEC.loader is None:
    raise RuntimeError("could not load apple release M0 preflight module")
PREFLIGHT = importlib.util.module_from_spec(MODULE_SPEC)
MODULE_SPEC.loader.exec_module(PREFLIGHT)


def run_live_preflight() -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT)],
        check=False,
        capture_output=True,
        text=True,
    )


def load_fixture(name: str) -> dict:
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))


def audit_fixtures(facts_name: str, policy_name: str) -> dict:
    return PREFLIGHT.audit(load_fixture(facts_name), load_fixture(policy_name))


def serialize_report(report: dict) -> str:
    return json.dumps(report, sort_keys=True, indent=2, ensure_ascii=False) + "\n"


class AppleReleaseM0PreflightTests(unittest.TestCase):
    def test_pass_fixture_passes_only_through_direct_audit_call(self) -> None:
        report = audit_fixtures("facts-pass.json", "policy-pass.json")
        self.assertEqual(report["status"], "PASS")
        self.assertEqual(report["findings"], [])
        self.assertTrue(
            all(gate["status"] == "PASS" for gate in report["gates"].values())
        )

    def test_report_is_deterministic(self) -> None:
        first = serialize_report(
            audit_fixtures("facts-pass.json", "policy-pass.json")
        )
        second = serialize_report(
            audit_fixtures("facts-pass.json", "policy-pass.json")
        )
        self.assertEqual(first, second)
        self.assertRegex(
            json.loads(first)["attestationDigest"], r"^sha256:[0-9a-f]{64}$"
        )

    def test_pending_policy_is_blocked(self) -> None:
        report = audit_fixtures("facts-pass.json", "policy-pending.json")
        self.assertEqual(report["status"], "BLOCKED")
        codes = {finding["code"] for finding in report["findings"]}
        self.assertIn("REVISION_UNDECIDED", codes)
        self.assertIn("DEVELOPMENT_TEAM_PENDING", codes)
        self.assertIn("PRODUCTION_ORIGIN_PENDING", codes)
        self.assertIn("BUILD_AND_ARCHIVE_UNPROVED", codes)
        self.assertIn("SIGNING_AND_PROVISIONING_UNPROVED", codes)
        self.assertIn("TESTFLIGHT_SMOKE_UNPROVED", codes)
        self.assertIn("APP_STORE_REVIEW_READINESS_UNPROVED", codes)
        self.assertEqual(report["gates"]["buildAndArchive"]["status"], "BLOCKED")
        self.assertEqual(report["gates"]["testFlightSmoke"]["status"], "BLOCKED")
        self.assertEqual(
            report["gates"]["appStoreReviewReadiness"]["status"], "BLOCKED"
        )

    def test_mismatched_policy_is_blocked(self) -> None:
        report = audit_fixtures("facts-pass.json", "policy-mismatch.json")
        self.assertEqual(report["status"], "BLOCKED")
        codes = {finding["code"] for finding in report["findings"]}
        self.assertIn("REVISION_MISMATCH", codes)
        self.assertIn("BUNDLE_IDENTIFIER_MISMATCH", codes)
        self.assertIn("PRODUCTION_ORIGIN_MISMATCH", codes)
        self.assertIn("APS_ENVIRONMENT_MISMATCH", codes)

    def test_dirty_source_is_blocked(self) -> None:
        report = audit_fixtures("facts-dirty.json", "policy-pass.json")
        self.assertEqual(report["status"], "BLOCKED")
        codes = {finding["code"] for finding in report["findings"]}
        self.assertIn("SOURCE_TREE_DIRTY", codes)

    def test_malformed_policy_is_rejected(self) -> None:
        with self.assertRaises(PREFLIGHT.PreflightInputError) as context:
            PREFLIGHT.audit(load_fixture("facts-pass.json"), {"schemaVersion": 2})
        self.assertIn("requires decisions and proofs", str(context.exception))

    def test_arbitrary_fixture_fields_are_not_serialized(self) -> None:
        facts = load_fixture("facts-pass.json")
        facts["secret"] = "DO_NOT_SERIALIZE"
        facts["build"]["provisioningProfileContent"] = "DO_NOT_SERIALIZE"
        report = PREFLIGHT.audit(facts, load_fixture("policy-pass.json"))
        serialized = serialize_report(report)
        self.assertNotIn("DO_NOT_SERIALIZE", serialized)
        self.assertNotIn("provisioningProfileContent", serialized)

    def test_live_collection_uses_static_project_resolver(self) -> None:
        result = run_live_preflight()
        self.assertEqual(result.returncode, 1, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "BLOCKED")
        self.assertEqual(
            report["facts"]["build"]["settingsResolver"],
            "pbxproj-static-iphoneos-release-v1",
        )
        self.assertEqual(report["facts"]["build"]["configuration"], "Release")
        self.assertEqual(report["facts"]["build"]["platformName"], "iphoneos")
        self.assertEqual(
            report["facts"]["build"]["bundleIdentifier"], "org.digipomps.haven"
        )
        self.assertEqual(
            report["facts"]["build"]["productionOrigin"],
            "https://haven.digipomps.org",
        )
        self.assertEqual(
            report["policy"]["decisions"]["bundleIdentifier"]["value"],
            "org.digipomps.haven",
        )
        self.assertEqual(
            report["policy"]["decisions"]["productionOrigin"]["value"],
            "https://haven.digipomps.org",
        )
        self.assertEqual(report["gates"]["buildAndArchive"]["status"], "BLOCKED")
        self.assertEqual(
            report["gates"]["signingAndProvisioning"]["status"], "BLOCKED"
        )
        self.assertEqual(report["gates"]["testFlightSmoke"]["status"], "BLOCKED")
        self.assertEqual(
            report["gates"]["appStoreReviewReadiness"]["status"], "BLOCKED"
        )
        self.assertRegex(report["sourceRevision"], r"^[0-9a-f]{40}$")

    def test_testflight_and_app_store_gates_depend_on_prior_gates(self) -> None:
        facts = load_fixture("facts-pass.json")
        policy = load_fixture("policy-pass.json")
        policy["proofs"]["signingAndProvisioning"]["status"] = "unproved"
        policy["proofs"]["signingAndProvisioning"]["evidenceReference"] = None
        report = PREFLIGHT.audit(facts, policy)
        self.assertEqual(report["gates"]["buildAndArchive"]["status"], "PASS")
        self.assertEqual(
            report["gates"]["signingAndProvisioning"]["status"], "BLOCKED"
        )
        self.assertEqual(report["gates"]["testFlightSmoke"]["status"], "BLOCKED")
        self.assertEqual(
            report["gates"]["appStoreReviewReadiness"]["status"], "BLOCKED"
        )
        self.assertIn(
            "SIGNING_AND_PROVISIONING_UNPROVED",
            report["gates"]["appStoreReviewReadiness"]["blockerCodes"],
        )

    def test_uncategorized_finding_blocks_every_gate(self) -> None:
        gates = PREFLIGHT.summarize_gates(
            [PREFLIGHT.finding("NEW_UNCATEGORIZED_CHECK", "fixture")]
        )
        self.assertTrue(all(gate["status"] == "BLOCKED" for gate in gates.values()))
        self.assertIn(
            "NEW_UNCATEGORIZED_CHECK",
            gates["appStoreReviewReadiness"]["blockerCodes"],
        )

    def test_production_origin_must_be_canonical_https_origin(self) -> None:
        invalid_values = (
            "http://example.org",
            "https://example.org/",
            "https://example.org/path",
            "https://user@example.org",
        )
        for value in invalid_values:
            with self.subTest(value=value):
                facts = load_fixture("facts-pass.json")
                facts["build"]["productionOrigin"] = value
                with self.assertRaises(PREFLIGHT.PreflightInputError) as context:
                    PREFLIGHT.audit(facts, load_fixture("policy-pass.json"))
                self.assertIn("productionOrigin", str(context.exception))

    def test_decided_null_apns_is_rejected(self) -> None:
        facts = load_fixture("facts-pass.json")
        policy = load_fixture("policy-pass.json")
        policy["decisions"]["apsEnvironment"]["value"] = None
        with self.assertRaises(PREFLIGHT.PreflightInputError) as context:
            PREFLIGHT.audit(facts, policy)
        self.assertIn("requires a non-null value when decided", str(context.exception))

    def test_missing_apns_entitlement_cannot_pass(self) -> None:
        facts = load_fixture("facts-pass.json")
        policy = load_fixture("policy-pass.json")
        facts["entitlements"]["apsEnvironment"] = None
        facts["entitlements"]["apsEnvironmentKeyPresent"] = False
        report = PREFLIGHT.audit(facts, policy)
        self.assertEqual(report["status"], "BLOCKED")
        codes = {finding["code"] for finding in report["findings"]}
        self.assertIn("APS_ENVIRONMENT_MISSING", codes)
        self.assertIn("APS_ENVIRONMENT_MISMATCH", codes)

    def test_invalid_apns_environment_is_rejected(self) -> None:
        for target in ("facts", "policy"):
            with self.subTest(target=target):
                facts = load_fixture("facts-pass.json")
                policy = load_fixture("policy-pass.json")
                if target == "facts":
                    facts["entitlements"]["apsEnvironment"] = "staging"
                else:
                    policy["decisions"]["apsEnvironment"]["value"] = "staging"
                with self.assertRaises(PREFLIGHT.PreflightInputError) as context:
                    PREFLIGHT.audit(facts, policy)
                self.assertIn("apsEnvironment", str(context.exception))

    def test_invalid_associated_domains_are_rejected(self) -> None:
        cases = (
            ("facts-duplicate", "facts", ["applinks:example.org", "applinks:example.org"]),
            ("facts-empty", "facts", [""]),
            ("policy-duplicate", "policy", ["applinks:example.org", "applinks:example.org"]),
            ("policy-empty", "policy", ["  "]),
        )
        for label, target, domains in cases:
            with self.subTest(label=label):
                facts = load_fixture("facts-pass.json")
                policy = load_fixture("policy-pass.json")
                if target == "facts":
                    facts["entitlements"]["associatedDomains"] = domains
                else:
                    policy["decisions"]["associatedDomains"]["value"] = domains
                with self.assertRaises(PREFLIGHT.PreflightInputError) as context:
                    PREFLIGHT.audit(facts, policy)
                self.assertIn("Associated Domains", str(context.exception))

    def test_explicit_empty_associated_domains_can_pass(self) -> None:
        facts = load_fixture("facts-pass.json")
        policy = load_fixture("policy-pass.json")
        facts["entitlements"]["associatedDomains"] = []
        facts["entitlements"]["associatedDomainsKeyPresent"] = False
        policy["decisions"]["associatedDomains"]["value"] = []
        report = PREFLIGHT.audit(facts, policy)
        self.assertEqual(report["status"], "PASS")

    def test_production_cli_and_wrapper_reject_facts_fixture(self) -> None:
        commands = (
            ("script", [sys.executable, str(SCRIPT)]),
            ("wrapper", [str(WRAPPER)]),
        )
        with tempfile.TemporaryDirectory() as directory:
            for label, command in commands:
                with self.subTest(label=label):
                    output = Path(directory) / f"{label}-report.json"
                    result = subprocess.run(
                        command
                        + [
                            "--facts-fixture",
                            str(FIXTURES / "facts-pass.json"),
                            "--policy",
                            str(FIXTURES / "policy-pass.json"),
                            "--output",
                            str(output),
                        ],
                        cwd=REPO_ROOT,
                        check=False,
                        capture_output=True,
                        text=True,
                    )
                    self.assertEqual(result.returncode, 2)
                    self.assertEqual(result.stdout, "")
                    self.assertFalse(output.exists())
                    self.assertIn("unrecognized arguments: --facts-fixture", result.stderr)


if __name__ == "__main__":
    unittest.main()
