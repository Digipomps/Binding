import Foundation
import CellBase

enum BindingConferenceConfigurationRepair {
    private static let participantPortalName = "conference participant portal dashboard"
    private static let controlTowerName = "conference control tower"

    static func updatedConfigurationIfNeeded(_ configuration: CellConfiguration) -> CellConfiguration? {
        switch normalizedName(for: configuration) {
        case participantPortalName:
            return updatedParticipantPortalConfigurationIfNeeded(configuration)
        case controlTowerName:
            return updatedControlTowerConfigurationIfNeeded(configuration)
        default:
            return nil
        }
    }

    static func reconcile(_ configuration: CellConfiguration) -> CellConfiguration {
        updatedConfigurationIfNeeded(configuration) ?? configuration
    }

    private static func updatedParticipantPortalConfigurationIfNeeded(_ configuration: CellConfiguration) -> CellConfiguration? {
        guard participantPortalNeedsRepair(configuration) else {
            return nil
        }

        return ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )
    }

    private static func updatedControlTowerConfigurationIfNeeded(_ configuration: CellConfiguration) -> CellConfiguration? {
        guard controlTowerNeedsRepair(configuration) else {
            return nil
        }

        return ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell:///ConferenceAdminPreviewShell"
        )
    }

    private static func participantPortalNeedsRepair(_ configuration: CellConfiguration) -> Bool {
        let references = configuration.cellReferences ?? []
        let hasAgendaSnapshotReference = references.contains(where: {
            $0.label == "agendaSnapshot" && endpointIdentity($0.endpoint) == endpointIdentity("cell:///ConferenceParticipantAgendaSnapshot")
        })
        let hasMatchmakingSnapshotReference = references.contains(where: {
            $0.label == "matchmakingSnapshot" && endpointIdentity($0.endpoint) == endpointIdentity("cell:///ConferenceParticipantMatchmakingSnapshot")
        })
        let hasDiscoverySnapshotReference = references.contains(where: {
            $0.label == "discoverySnapshot" && endpointIdentity($0.endpoint) == endpointIdentity("cell:///ConferenceParticipantDiscoverySnapshot")
        })
        let hasNearbyRadarReference = references.contains(where: {
            $0.label == "nearbyRadar" && endpointIdentity($0.endpoint) == endpointIdentity("cell:///ConferenceNearbyRadar")
        })
        let skeletonJSON = serializedSkeleton(configuration.skeleton)
        let hasAgendaSnapshotBindings = skeletonJSON.contains("\"agendaSnapshot.state.statusSummary\"")
            && skeletonJSON.contains("\"agendaSnapshot.state.modeChoices\"")
            && skeletonJSON.contains("\"agendaSnapshot.state.trackChoices\"")
            && skeletonJSON.contains("\"agendaSnapshot.state.focusedActions\"")
            && skeletonJSON.contains("\"keypath\":\"agendaSnapshot.dispatchAction\"")
        let hasMatchmakingSnapshotBindings = skeletonJSON.contains("\"matchmakingSnapshot.state.statusSummary\"")
            && skeletonJSON.contains("\"matchmakingSnapshot.state.focusedProfile.title\"")
            && skeletonJSON.contains("\"keypath\":\"matchmakingSnapshot.dispatchAction\"")
        let hasDiscoverySnapshotBindings = skeletonJSON.contains("\"discoverySnapshot.state.statusSummary\"")
            && skeletonJSON.contains("\"discoverySnapshot.state.focusedProfile.title\"")
            && skeletonJSON.contains("\"keypath\":\"discoverySnapshot.dispatchAction\"")
        let hasNearbyActionBindings = skeletonJSON.contains("\"keypath\":\"nearbyRadar.dispatchAction\"")
        let hasNearbySnapshotReference = skeletonJSON.contains("\"nearbyRadar.snapshot\"")

        return !(hasAgendaSnapshotReference && hasAgendaSnapshotBindings && hasMatchmakingSnapshotReference && hasMatchmakingSnapshotBindings && hasDiscoverySnapshotReference && hasDiscoverySnapshotBindings && hasNearbyRadarReference && hasNearbyActionBindings && hasNearbySnapshotReference)
    }
    private static func controlTowerNeedsRepair(_ configuration: CellConfiguration) -> Bool {
        let references = configuration.cellReferences ?? []
        let hasAdminReference = references.contains(where: {
            $0.label == "conferenceAdminShell"
                && endpointIdentity($0.endpoint) == endpointIdentity("cell:///ConferenceAdminPreviewShell")
        })
        let skeletonJSON = serializedSkeleton(configuration.skeleton)
        let hasCurrentBindings = skeletonJSON.contains("\"conferenceAdminShell.state.workspace.title\"")
            && skeletonJSON.contains("\"conferenceAdminShell.state.content.intro\"")
            && skeletonJSON.contains("\"conferenceAdminShell.state.operations.intro\"")
            && skeletonJSON.contains("\"conferenceAdminShell.state.insights.dashboardSummary\"")
            && skeletonJSON.contains("\"contentPublishing.publishDraft\"")
            && skeletonJSON.contains("\"contentPublishing.discardDraft\"")

        return !(hasAdminReference && hasCurrentBindings)
    }
    private static func normalizedName(for configuration: CellConfiguration) -> String {
        configuration.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func serializedSkeleton(_ skeleton: SkeletonElement?) -> String {
        guard let skeleton,
              let data = try? JSONEncoder().encode(skeleton) else {
            return ""
        }
        return String(decoding: data, as: UTF8.self)
    }

    private static func endpointIdentity(_ endpoint: String) -> String {
        if let components = URLComponents(string: endpoint) {
            let scheme = components.scheme?.lowercased() ?? ""
            let host = (components.host ?? "").lowercased()
            let path = components.path.lowercased()
            return "\(scheme)|\(host)|\(path)"
        }
        return endpoint.lowercased()
    }
}
