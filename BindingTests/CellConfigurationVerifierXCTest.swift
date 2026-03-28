import XCTest
@testable import Binding

#if canImport(AppKit)
import AppKit
#endif

final class CellConfigurationVerifierXCTest: XCTestCase {
    func testConferenceParticipantPortalContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Vis timeline",
                "Oppdater treff",
                "Åpne profil",
                "Start chat",
                "Marker for oppfølging",
                "Oppdater discovery",
                "Start scanner",
                "Stop scanner",
                "Åpne full radar",
                "Start group chat"
            ]
        )

        XCTAssertEqual(
            report.validation.errorCount,
            0,
            "Validation issues: \(report.validation.issues)"
        )
        XCTAssertTrue(
            report.unresolvedReferences.isEmpty,
            "Unresolved references: \(report.unresolvedReferences)"
        )
        XCTAssertTrue(
            report.unreadableRootProbes.isEmpty,
            "Unreadable root probes: \(report.unreadableRootProbes)"
        )
        XCTAssertTrue(
            report.failedActions.isEmpty,
            "Failed actions: \(report.failedActions)"
        )
    }

    func testConferenceControlTowerContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell:///ConferenceAdminPreviewShell"
        )

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Publish content",
                "Discard draft"
            ]
        )

        XCTAssertEqual(
            report.validation.errorCount,
            0,
            "Validation issues: \(report.validation.issues)"
        )
        XCTAssertTrue(
            report.unresolvedReferences.isEmpty,
            "Unresolved references: \(report.unresolvedReferences)"
        )
        XCTAssertTrue(
            report.unreadableRootProbes.isEmpty,
            "Unreadable root probes: \(report.unreadableRootProbes)"
        )
        XCTAssertTrue(
            report.failedActions.isEmpty,
            "Failed actions: \(report.failedActions)"
        )
    }

    func testConferenceNearbyRadarContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceNearbyRadarWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Start scanner",
                "Stop scanner",
                "Tilbake til deltagerportal"
            ]
        )

        XCTAssertEqual(report.validation.errorCount, 0, "Validation issues: \(report.validation.issues)")
        XCTAssertTrue(report.unresolvedReferences.isEmpty, "Unresolved references: \(report.unresolvedReferences)")
        XCTAssertTrue(report.unreadableRootProbes.isEmpty, "Unreadable root probes: \(report.unreadableRootProbes)")
        XCTAssertTrue(report.failedActions.isEmpty, "Failed actions: \(report.failedActions)")
    }

    func testConferenceNearbyParticipantProfileContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceNearbyParticipantWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Åpne full radar",
                "Tilbake til deltagerportal"
            ]
        )

        XCTAssertEqual(report.validation.errorCount, 0, "Validation issues: \(report.validation.issues)")
        XCTAssertTrue(report.unresolvedReferences.isEmpty, "Unresolved references: \(report.unresolvedReferences)")
        XCTAssertTrue(report.unreadableRootProbes.isEmpty, "Unreadable root probes: \(report.unreadableRootProbes)")
        XCTAssertTrue(report.failedActions.isEmpty, "Failed actions: \(report.failedActions)")
    }

    func testConferenceParticipantNearbyFollowUpContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )

        let report = try await CellConfigurationVerifier.nearbyFollowUpReport(for: configuration)

        XCTAssertEqual(report.startOutcome, "ok")
        XCTAssertEqual(report.statusAfterStart, "started")
        XCTAssertEqual(report.requestContactOutcome, "ok")
        XCTAssertEqual(report.requestContactLabel, "Contact pending")
        XCTAssertEqual(report.requestContactSummary, "Signed contact request sent. Waiting for acceptance.")
        XCTAssertEqual(report.requestContactActionSummary, "Signed contact request sent. Waiting for acceptance.")
        XCTAssertEqual(report.openChatOutcome, "ok")
        XCTAssertEqual(report.nearbyCardLabel, "Open chat")
        XCTAssertTrue(report.nearbyCardPurposeSummary?.contains("verified overlap") == true)
        XCTAssertEqual(report.nearbyActionSummary, "Started a conference follow-up chat with Nora Berg.")
        XCTAssertEqual(report.workspaceNextStep, "Started follow-up chat with Nora Berg in local preview.")
        XCTAssertEqual(report.sharedChatSummary, "1 shared message(s) visible.")
        XCTAssertEqual(report.firstRecentMessage, "Nearby follow-up with Nora Berg is ready in discovery chat.")
        XCTAssertEqual(report.stopOutcome, "ok")
        XCTAssertEqual(report.statusAfterStop, "stopped")
    }

#if canImport(AppKit)
    @MainActor
    func testConferenceParticipantPortalRenderer() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Conference Participant Portal",
                "Entity Discovery",
                "Start scanner"
            ]
        )

        XCTAssertGreaterThan(report.snapshotByteCount, 0, "Expected rendered snapshot bytes")
        XCTAssertGreaterThan(report.subviewCount, 0, "Expected rendered subviews")
        XCTAssertGreaterThan(report.totalRenderMilliseconds, 0, "Expected positive render duration")
    }

    @MainActor
    func testConferenceControlTowerRenderer() async throws {
        let configuration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell:///ConferenceAdminPreviewShell"
        )

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Conference Control Tower",
                "Publish content",
                "Operations & Insights"
            ]
        )

        XCTAssertGreaterThan(report.snapshotByteCount, 0, "Expected rendered snapshot bytes")
        XCTAssertGreaterThan(report.subviewCount, 0, "Expected rendered subviews")
        XCTAssertGreaterThan(report.totalRenderMilliseconds, 0, "Expected positive render duration")
    }

    @MainActor
    func testConferenceNearbyRadarRenderer() async throws {
        let configuration = ConfigurationCatalogCell.conferenceNearbyRadarWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Conference Nearby Radar",
                "Start scanner",
                "Tilbake til deltagerportal",
                "Valgt deltager"
            ]
        )

        XCTAssertGreaterThan(report.snapshotByteCount, 0, "Expected rendered snapshot bytes")
        XCTAssertGreaterThan(report.subviewCount, 0, "Expected rendered subviews")
        XCTAssertGreaterThan(report.totalRenderMilliseconds, 0, "Expected positive render duration")
    }

    @MainActor
    func testConferenceNearbyParticipantProfileRenderer() async throws {
        let configuration = ConfigurationCatalogCell.conferenceNearbyParticipantWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Nearby Participant Profile",
                "Åpne full radar",
                "Tilbake til deltagerportal",
                "Neste steg"
            ]
        )

        XCTAssertGreaterThan(report.snapshotByteCount, 0, "Expected rendered snapshot bytes")
        XCTAssertGreaterThan(report.subviewCount, 0, "Expected rendered subviews")
        XCTAssertGreaterThan(report.totalRenderMilliseconds, 0, "Expected positive render duration")
    }
#endif
}
