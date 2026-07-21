#!/usr/bin/env python3
"""Fail-closed, unsigned Apple release M0 preflight for Binding.

The report is deterministic for the same source tree, policy, and statically
resolved project settings. It intentionally excludes timestamps, environment
dumps, signing material, and provisioning profile names or contents.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit


SCHEMA_VERSION = 2
REVISION_PATTERN = re.compile(r"^[0-9a-f]{40}$")
APNS_ENVIRONMENTS = {"development", "production"}
BUILD_SETTING_ALLOWLIST = {
    "CODE_SIGN_ENTITLEMENTS",
    "CODE_SIGN_IDENTITY",
    "CODE_SIGN_STYLE",
    "CONFIGURATION",
    "CURRENT_PROJECT_VERSION",
    "DEVELOPMENT_TEAM",
    "HAVEN_PRODUCTION_ORIGIN",
    "MARKETING_VERSION",
    "PLATFORM_NAME",
    "PRODUCT_BUNDLE_IDENTIFIER",
    "PRODUCT_NAME",
    "PROVISIONING_PROFILE_SPECIFIER",
    "SDKROOT",
}
DECISION_FIELDS = {
    "developmentTeam": str,
    "bundleIdentifier": str,
    "productionOrigin": str,
    "associatedDomains": list,
    "apsEnvironment": str,
}
PROOF_FIELDS = (
    "buildAndArchive",
    "signingAndProvisioning",
    "testFlightSmoke",
    "appStoreReviewReadiness",
)
GATE_ORDER = (
    "buildAndArchive",
    "signingAndProvisioning",
    "testFlightSmoke",
    "appStoreReviewReadiness",
)
GATE_FINDING_PREFIXES = {
    "buildAndArchive": (
        "REVISION_",
        "SOURCE_TREE_",
        "CONFIGURATION_",
        "PLATFORM_",
        "MARKETING_VERSION_",
        "BUILD_NUMBER_",
        "BUNDLE_IDENTIFIER_",
        "PRODUCTION_ORIGIN_",
        "BUILD_AND_ARCHIVE_",
    ),
    "signingAndProvisioning": (
        "DEVELOPMENT_TEAM_",
        "ASSOCIATED_DOMAINS_",
        "APS_ENVIRONMENT_",
        "SIGNING_AND_PROVISIONING_",
    ),
    "testFlightSmoke": ("TESTFLIGHT_SMOKE_",),
    "appStoreReviewReadiness": ("APP_STORE_REVIEW_READINESS_",),
}
CODE_PREFIXES = {
    "developmentTeam": "DEVELOPMENT_TEAM",
    "bundleIdentifier": "BUNDLE_IDENTIFIER",
    "productionOrigin": "PRODUCTION_ORIGIN",
    "associatedDomains": "ASSOCIATED_DOMAINS",
    "apsEnvironment": "APS_ENVIRONMENT",
    "buildAndArchive": "BUILD_AND_ARCHIVE",
    "signingAndProvisioning": "SIGNING_AND_PROVISIONING",
    "testFlightSmoke": "TESTFLIGHT_SMOKE",
    "appStoreReviewReadiness": "APP_STORE_REVIEW_READINESS",
}


class PreflightInputError(Exception):
    """The audit could not safely interpret its inputs."""


def run_checked(command: list[str], cwd: Path) -> str:
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError as error:
        raise PreflightInputError(f"could not execute {command[0]}") from error
    if result.returncode != 0:
        # Raw stdout/stderr can contain host paths or tool configuration. Never
        # copy them into release audit material.
        raise PreflightInputError(
            f"{command[0]} failed with exit code {result.returncode}"
        )
    return result.stdout


def load_json(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            value = json.load(handle)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise PreflightInputError(f"could not read valid JSON from {path}") from error
    if not isinstance(value, dict):
        raise PreflightInputError(f"expected a JSON object in {path}")
    return value


def release_configuration(
    objects: dict[str, Any], configuration_list_id: str, owner: str
) -> dict[str, Any]:
    configuration_list = objects.get(configuration_list_id)
    if not isinstance(configuration_list, dict):
        raise PreflightInputError(f"{owner} build configuration list is missing")
    configuration_ids = configuration_list.get("buildConfigurations")
    if not isinstance(configuration_ids, list):
        raise PreflightInputError(f"{owner} build configurations are malformed")
    matches = [
        objects.get(identifier)
        for identifier in configuration_ids
        if isinstance(objects.get(identifier), dict)
        and objects[identifier].get("name") == "Release"
    ]
    if len(matches) != 1:
        raise PreflightInputError(f"{owner} must have exactly one Release configuration")
    configuration = matches[0]
    if configuration.get("baseConfigurationReference"):
        # This resolver intentionally has no xcconfig parser. Refuse to report
        # partially resolved values if one is introduced later.
        raise PreflightInputError(f"{owner} Release uses an unsupported base xcconfig")
    settings = configuration.get("buildSettings")
    if not isinstance(settings, dict):
        raise PreflightInputError(f"{owner} Release build settings are malformed")
    return settings


def collect_build_settings(repo_root: Path) -> dict[str, str]:
    project_path = repo_root / "Binding.xcodeproj" / "project.pbxproj"
    output = run_checked(
        ["plutil", "-convert", "json", "-o", "-", str(project_path)], repo_root
    )
    try:
        project = json.loads(output)
    except json.JSONDecodeError as error:
        raise PreflightInputError("plutil returned invalid project JSON") from error
    objects = project.get("objects")
    root_object_id = project.get("rootObject")
    if not isinstance(objects, dict) or not isinstance(root_object_id, str):
        raise PreflightInputError("Xcode project object graph is malformed")
    root_object = objects.get(root_object_id)
    if not isinstance(root_object, dict) or root_object.get("isa") != "PBXProject":
        raise PreflightInputError("Xcode project root object is malformed")

    targets = [
        value
        for value in objects.values()
        if isinstance(value, dict)
        and value.get("isa") == "PBXNativeTarget"
        and value.get("name") == "HAVEN"
    ]
    if len(targets) != 1:
        raise PreflightInputError("Xcode project must contain exactly one HAVEN target")
    target = targets[0]
    project_configuration_list = root_object.get("buildConfigurationList")
    target_configuration_list = target.get("buildConfigurationList")
    if not isinstance(project_configuration_list, str) or not isinstance(
        target_configuration_list, str
    ):
        raise PreflightInputError("Xcode project configuration references are malformed")

    merged: dict[str, Any] = {}
    merged.update(
        release_configuration(objects, project_configuration_list, "project")
    )
    merged.update(release_configuration(objects, target_configuration_list, "HAVEN target"))

    settings: dict[str, str] = {
        "CONFIGURATION": "Release",
        "PLATFORM_NAME": "iphoneos",
        "SDKROOT": "iphoneos",
    }
    for key in BUILD_SETTING_ALLOWLIST:
        conditional_key = f"{key}[sdk=iphoneos*]"
        raw_value = merged.get(conditional_key, merged.get(key))
        if raw_value is None:
            continue
        if not isinstance(raw_value, (str, int, float, bool)):
            raise PreflightInputError(f"build setting {key} has an unsupported value type")
        value = str(raw_value).strip()
        value = value.replace("$(TARGET_NAME)", "HAVEN").replace("${TARGET_NAME}", "HAVEN")
        settings[key] = value

    required = {
        "CODE_SIGN_ENTITLEMENTS",
        "CONFIGURATION",
        "CURRENT_PROJECT_VERSION",
        "DEVELOPMENT_TEAM",
        "HAVEN_PRODUCTION_ORIGIN",
        "MARKETING_VERSION",
        "PLATFORM_NAME",
        "PRODUCT_BUNDLE_IDENTIFIER",
    }
    missing = sorted(required - settings.keys())
    if missing:
        raise PreflightInputError(
            "project omitted required allowlisted settings: " + ", ".join(missing)
        )
    unresolved = [
        key
        for key in required
        if "$(" in settings[key] or "${" in settings[key]
    ]
    if unresolved:
        raise PreflightInputError(
            "critical project settings contain unresolved variables: "
            + ", ".join(sorted(unresolved))
        )
    return settings


def validate_associated_domains(value: Any, owner: str) -> None:
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise PreflightInputError(f"{owner} Associated Domains must be a string array")
    if any(not item.strip() or item != item.strip() for item in value):
        raise PreflightInputError(
            f"{owner} Associated Domains cannot contain empty or padded strings"
        )
    if len(value) != len(set(value)):
        raise PreflightInputError(f"{owner} Associated Domains cannot contain duplicates")


def validate_production_origin(value: Any, owner: str) -> None:
    if not isinstance(value, str) or not value.strip() or value != value.strip():
        raise PreflightInputError(f"{owner} productionOrigin must be a non-empty string")
    parsed = urlsplit(value)
    if (
        parsed.scheme != "https"
        or not parsed.hostname
        or parsed.username is not None
        or parsed.password is not None
        or parsed.path
        or parsed.query
        or parsed.fragment
        or value != f"https://{parsed.netloc.lower()}"
    ):
        raise PreflightInputError(
            f"{owner} productionOrigin must be a canonical HTTPS origin without a path"
        )


def collect_live_facts(repo_root: Path) -> dict[str, Any]:
    revision = run_checked(["git", "rev-parse", "HEAD"], repo_root).strip()
    if not REVISION_PATTERN.fullmatch(revision):
        raise PreflightInputError("git returned a non-canonical source revision")
    dirty_lines = run_checked(
        ["git", "status", "--porcelain", "--untracked-files=all"], repo_root
    ).splitlines()

    settings = collect_build_settings(repo_root)
    entitlements_setting = settings["CODE_SIGN_ENTITLEMENTS"]
    entitlements_path = (repo_root / entitlements_setting).resolve()
    try:
        entitlements_path.relative_to(repo_root.resolve())
    except ValueError as error:
        raise PreflightInputError("resolved entitlements path escapes the repository") from error
    if not entitlements_path.is_file():
        raise PreflightInputError("resolved entitlements file does not exist")
    try:
        with entitlements_path.open("rb") as handle:
            entitlements = plistlib.load(handle)
    except (OSError, plistlib.InvalidFileException) as error:
        raise PreflightInputError("resolved entitlements file is not a valid plist") from error
    if not isinstance(entitlements, dict):
        raise PreflightInputError("resolved entitlements plist is not a dictionary")

    associated_domains = entitlements.get("com.apple.developer.associated-domains", [])
    validate_associated_domains(associated_domains, "observed")
    aps_environment = entitlements.get("aps-environment")
    if aps_environment is not None and aps_environment not in APNS_ENVIRONMENTS:
        raise PreflightInputError(
            "observed APNS environment must be development or production"
        )

    # These are the only live values allowed into the report. In particular,
    # provisioning names/content, certificates, environment variables, and raw
    # tool output are excluded.
    return {
        "schemaVersion": SCHEMA_VERSION,
        "source": {
            "revision": revision,
            "treeClean": not dirty_lines,
            "dirtyEntryCount": len(dirty_lines),
        },
        "build": {
            "settingsResolver": "pbxproj-static-iphoneos-release-v1",
            "configuration": settings["CONFIGURATION"],
            "platformName": settings["PLATFORM_NAME"],
            "sdkRoot": settings.get("SDKROOT", ""),
            "productName": settings.get("PRODUCT_NAME", ""),
            "developmentTeam": settings["DEVELOPMENT_TEAM"],
            "bundleIdentifier": settings["PRODUCT_BUNDLE_IDENTIFIER"],
            "productionOrigin": settings["HAVEN_PRODUCTION_ORIGIN"],
            "entitlementsPath": entitlements_setting,
            "codeSignStyle": settings.get("CODE_SIGN_STYLE", ""),
            "codeSignIdentityKind": normalize_code_sign_identity(
                settings.get("CODE_SIGN_IDENTITY", "")
            ),
            "provisioningProfileSpecifierPresent": bool(
                settings.get("PROVISIONING_PROFILE_SPECIFIER", "")
            ),
            "marketingVersion": settings["MARKETING_VERSION"],
            "buildNumber": settings["CURRENT_PROJECT_VERSION"],
        },
        "entitlements": {
            "associatedDomains": sorted(associated_domains),
            "associatedDomainsKeyPresent": (
                "com.apple.developer.associated-domains" in entitlements
            ),
            "apsEnvironment": aps_environment,
            "apsEnvironmentKeyPresent": "aps-environment" in entitlements,
        },
    }


def validate_facts(facts: dict[str, Any]) -> None:
    if facts.get("schemaVersion") != SCHEMA_VERSION:
        raise PreflightInputError("facts schemaVersion is not supported")
    source = facts.get("source")
    build = facts.get("build")
    entitlements = facts.get("entitlements")
    if not isinstance(source, dict) or not isinstance(build, dict) or not isinstance(
        entitlements, dict
    ):
        raise PreflightInputError("facts require source, build, and entitlements objects")
    if not REVISION_PATTERN.fullmatch(str(source.get("revision", ""))):
        raise PreflightInputError("facts source revision is not a full SHA-1")
    if not isinstance(source.get("treeClean"), bool):
        raise PreflightInputError("facts treeClean must be boolean")
    required_strings = (
        "configuration",
        "platformName",
        "developmentTeam",
        "bundleIdentifier",
        "productionOrigin",
        "entitlementsPath",
        "marketingVersion",
        "buildNumber",
    )
    if any(not isinstance(build.get(field), str) for field in required_strings):
        raise PreflightInputError("facts build fields have invalid types")
    validate_production_origin(build["productionOrigin"], "facts")
    domains = entitlements.get("associatedDomains")
    validate_associated_domains(domains, "facts")
    aps_environment = entitlements.get("apsEnvironment")
    if aps_environment is not None and aps_environment not in APNS_ENVIRONMENTS:
        raise PreflightInputError(
            "facts apsEnvironment must be development, production, or null"
        )
    aps_key_present = entitlements.get("apsEnvironmentKeyPresent")
    if not isinstance(aps_key_present, bool):
        raise PreflightInputError("facts apsEnvironmentKeyPresent must be boolean")
    if not aps_key_present and aps_environment is not None:
        raise PreflightInputError(
            "facts apsEnvironment must be null when its entitlement key is absent"
        )


def sanitize_facts(facts: dict[str, Any]) -> dict[str, Any]:
    """Project arbitrary fixture/live input onto the report's public allowlist."""
    source = facts["source"]
    build = facts["build"]
    entitlements = facts["entitlements"]
    return {
        "schemaVersion": SCHEMA_VERSION,
        "source": {
            "revision": source["revision"],
            "treeClean": source["treeClean"],
            "dirtyEntryCount": source.get("dirtyEntryCount", 0),
        },
        "build": {
            "settingsResolver": build.get("settingsResolver", "fixture"),
            "configuration": build["configuration"],
            "platformName": build["platformName"],
            "sdkRoot": build.get("sdkRoot", ""),
            "productName": build.get("productName", ""),
            "developmentTeam": build["developmentTeam"],
            "bundleIdentifier": build["bundleIdentifier"],
            "productionOrigin": build["productionOrigin"],
            "entitlementsPath": build["entitlementsPath"],
            "codeSignStyle": build.get("codeSignStyle", ""),
            "codeSignIdentityKind": normalize_code_sign_identity(
                build.get("codeSignIdentityKind", "")
            ),
            "provisioningProfileSpecifierPresent": bool(
                build.get("provisioningProfileSpecifierPresent", False)
            ),
            "marketingVersion": build["marketingVersion"],
            "buildNumber": build["buildNumber"],
        },
        "entitlements": {
            "associatedDomains": sorted(entitlements["associatedDomains"]),
            "associatedDomainsKeyPresent": bool(
                entitlements.get("associatedDomainsKeyPresent", False)
            ),
            "apsEnvironment": entitlements.get("apsEnvironment"),
            "apsEnvironmentKeyPresent": bool(
                entitlements.get("apsEnvironmentKeyPresent", False)
            ),
        },
    }


def validate_policy(policy: dict[str, Any]) -> None:
    if policy.get("schemaVersion") != SCHEMA_VERSION:
        raise PreflightInputError("policy schemaVersion is not supported")
    expected_revision = policy.get("expectedRevision")
    if expected_revision is not None and not REVISION_PATTERN.fullmatch(
        str(expected_revision)
    ):
        raise PreflightInputError("policy expectedRevision must be null or a full SHA-1")

    decisions = policy.get("decisions")
    proofs = policy.get("proofs")
    if not isinstance(decisions, dict) or not isinstance(proofs, dict):
        raise PreflightInputError("policy requires decisions and proofs objects")
    for name, expected_type in DECISION_FIELDS.items():
        decision = decisions.get(name)
        if not isinstance(decision, dict):
            raise PreflightInputError(f"policy decision {name} must be an object")
        if decision.get("status") not in {"pending", "decided"}:
            raise PreflightInputError(f"policy decision {name} has an invalid status")
        value = decision.get("value")
        if value is not None and not isinstance(value, expected_type):
            raise PreflightInputError(f"policy decision {name} has an invalid value type")
        if decision.get("status") == "decided":
            if value is None:
                raise PreflightInputError(
                    f"policy decision {name} requires a non-null value when decided"
                )
            if name in {
                "developmentTeam",
                "bundleIdentifier",
                "productionOrigin",
                "apsEnvironment",
            } and (
                not isinstance(value, str) or not value.strip()
            ):
                raise PreflightInputError(
                    f"policy decision {name} requires a non-empty string when decided"
                )
        if name == "associatedDomains" and value is not None:
            validate_associated_domains(value, "policy")
        if name == "productionOrigin" and value is not None:
            validate_production_origin(value, "policy")
        if name == "apsEnvironment" and value is not None and value not in APNS_ENVIRONMENTS:
            raise PreflightInputError(
                "policy apsEnvironment must be development or production"
            )
        decision_record = decision.get("decisionRecord")
        if decision_record is not None and not isinstance(decision_record, str):
            raise PreflightInputError(f"policy decision {name} decisionRecord must be a string")
    for name in PROOF_FIELDS:
        proof = proofs.get(name)
        if not isinstance(proof, dict):
            raise PreflightInputError(f"policy proof {name} must be an object")
        if proof.get("status") not in {"unproved", "proved"}:
            raise PreflightInputError(f"policy proof {name} has an invalid status")
        evidence_reference = proof.get("evidenceReference")
        if evidence_reference is not None and not isinstance(evidence_reference, str):
            raise PreflightInputError(
                f"policy proof {name} evidenceReference must be a string"
            )


def finding(code: str, summary: str) -> dict[str, str]:
    return {"code": code, "severity": "blocker", "summary": summary}


def has_text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def normalize_code_sign_identity(value: Any) -> str:
    if not isinstance(value, str) or not value.strip():
        return "Unset"
    if value.startswith("Apple Development"):
        return "Apple Development"
    if value.startswith("Apple Distribution"):
        return "Apple Distribution"
    return "Other"


def summarize_gates(findings: list[dict[str, str]]) -> dict[str, dict[str, Any]]:
    gates: dict[str, dict[str, Any]] = {}
    finding_codes = {finding_item["code"] for finding_item in findings}
    classified_codes = {
        code
        for code in finding_codes
        if any(
            code.startswith(GATE_FINDING_PREFIXES[gate_name])
            for gate_name in GATE_ORDER
        )
    }
    # A new finding must never leave every named gate green merely because its
    # prefix has not been categorized yet. Treat it as an earliest-gate blocker.
    cumulative_codes = sorted(finding_codes - classified_codes)
    previous_gate = None
    for gate_name in GATE_ORDER:
        prefixes = GATE_FINDING_PREFIXES[gate_name]
        local_codes = sorted(
            finding_item["code"]
            for finding_item in findings
            if finding_item["code"].startswith(prefixes)
        )
        cumulative_codes = sorted(set(cumulative_codes + local_codes))
        gates[gate_name] = {
            "status": "PASS" if not cumulative_codes else "BLOCKED",
            "dependsOn": previous_gate,
            "blockerCodes": cumulative_codes,
        }
        previous_gate = gate_name
    return gates


def audit(facts: dict[str, Any], policy: dict[str, Any]) -> dict[str, Any]:
    validate_facts(facts)
    validate_policy(policy)
    facts = sanitize_facts(facts)
    findings: list[dict[str, str]] = []
    source = facts["source"]
    build = facts["build"]
    entitlements = facts["entitlements"]
    decisions = policy["decisions"]
    proofs = policy["proofs"]

    expected_revision = policy.get("expectedRevision")
    if expected_revision is None:
        findings.append(finding("REVISION_UNDECIDED", "Expected release revision is pending"))
    elif expected_revision != source["revision"]:
        findings.append(finding("REVISION_MISMATCH", "Observed revision differs from policy"))
    if not source["treeClean"]:
        findings.append(finding("SOURCE_TREE_DIRTY", "Source tree has uncommitted entries"))

    if build["configuration"] != "Release":
        findings.append(finding("CONFIGURATION_NOT_RELEASE", "Resolved configuration is not Release"))
    if build["platformName"] != "iphoneos":
        findings.append(finding("PLATFORM_NOT_IPHONEOS", "Resolved platform is not iphoneos"))
    if not build["marketingVersion"]:
        findings.append(finding("MARKETING_VERSION_MISSING", "Marketing version is empty"))
    if not build["buildNumber"]:
        findings.append(finding("BUILD_NUMBER_MISSING", "Build number is empty"))
    if not entitlements.get("apsEnvironmentKeyPresent") or entitlements.get(
        "apsEnvironment"
    ) is None:
        findings.append(
            finding(
                "APS_ENVIRONMENT_MISSING",
                "Observed APNS environment entitlement is missing",
            )
        )

    observed_values = {
        "developmentTeam": build["developmentTeam"],
        "bundleIdentifier": build["bundleIdentifier"],
        "productionOrigin": build["productionOrigin"],
        "associatedDomains": sorted(entitlements["associatedDomains"]),
        "apsEnvironment": entitlements.get("apsEnvironment"),
    }
    for name in sorted(DECISION_FIELDS):
        decision = decisions[name]
        code_prefix = CODE_PREFIXES[name]
        if decision["status"] != "decided":
            findings.append(
                finding(f"{code_prefix}_PENDING", f"Decision {name} is pending")
            )
            continue
        if not has_text(decision.get("decisionRecord")):
            findings.append(
                finding(
                    f"{code_prefix}_RECORD_MISSING",
                    f"Decision {name} has no decision record",
                )
            )
        expected_value = decision.get("value")
        if isinstance(expected_value, list):
            expected_value = sorted(set(expected_value))
        if expected_value != observed_values[name]:
            findings.append(
                finding(f"{code_prefix}_MISMATCH", f"Observed {name} differs from policy")
            )

    for name in PROOF_FIELDS:
        proof = proofs[name]
        code_prefix = CODE_PREFIXES[name]
        if proof["status"] != "proved":
            findings.append(finding(f"{code_prefix}_UNPROVED", f"Proof {name} is missing"))
        elif not has_text(proof.get("evidenceReference")):
            findings.append(
                finding(
                    f"{code_prefix}_EVIDENCE_REFERENCE_MISSING",
                    f"Proof {name} has no evidence reference",
                )
            )

    policy_summary = {
        "expectedRevision": expected_revision,
        "decisions": {
            name: {
                "status": decisions[name]["status"],
                "value": decisions[name].get("value"),
                "decisionRecordPresent": has_text(decisions[name].get("decisionRecord")),
            }
            for name in sorted(DECISION_FIELDS)
        },
        "proofs": {
            name: {
                "status": proofs[name]["status"],
                "evidenceReferencePresent": has_text(
                    proofs[name].get("evidenceReference")
                ),
            }
            for name in sorted(PROOF_FIELDS)
        },
    }
    report_core = {
        "schemaVersion": SCHEMA_VERSION,
        "status": "PASS" if not findings else "BLOCKED",
        "sourceRevision": source["revision"],
        "facts": facts,
        "policy": policy_summary,
        "gates": summarize_gates(findings),
        "findings": sorted(findings, key=lambda item: item["code"]),
    }
    canonical_core = json.dumps(
        report_core, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")
    report_core["attestationDigest"] = "sha256:" + hashlib.sha256(canonical_core).hexdigest()
    return report_core


def write_report(report: dict[str, Any], output: str) -> None:
    serialized = json.dumps(report, sort_keys=True, indent=2, ensure_ascii=False) + "\n"
    if output == "-":
        sys.stdout.write(serialized)
        return
    output_path = Path(output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(serialized, encoding="utf-8")


def parse_args() -> argparse.Namespace:
    script_path = Path(__file__).resolve()
    default_root = script_path.parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--policy",
        type=Path,
        default=default_root / "Documentation" / "AppleReleaseM0Policy.template.json",
    )
    parser.add_argument("--output", default="-", help="Report path, or - for stdout")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        repo_root = Path(__file__).resolve().parent.parent
        facts = collect_live_facts(repo_root)
        policy = load_json(args.policy)
        report = audit(facts, policy)
        write_report(report, args.output)
        return 0 if report["status"] == "PASS" else 1
    except PreflightInputError as error:
        # Do not serialize partial/raw inputs when validation or collection fails.
        sys.stderr.write(f"apple release M0 preflight error: {error}\n")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
