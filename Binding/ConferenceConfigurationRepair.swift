import Foundation
import CellBase

enum BindingConferenceConfigurationRepair {
    private static let participantPortalName = "conference participant portal dashboard"

    static func updatedConfigurationIfNeeded(_ configuration: CellConfiguration) -> CellConfiguration? {
        switch normalizedName(for: configuration) {
        case participantPortalName:
            return updatedParticipantPortalConfigurationIfNeeded(configuration)
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

        let endpoint = participantPortalEndpoint(from: configuration)
        return ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(endpoint: endpoint)
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
            && skeletonJSON.contains("\"agendaSnapshot.state.focusedActions\"")
            && skeletonJSON.contains("\"url\":\"cell:///ConferenceParticipantAgendaSnapshot\"")
        let hasMatchmakingSnapshotBindings = skeletonJSON.contains("\"matchmakingSnapshot.state.statusSummary\"")
            && skeletonJSON.contains("\"matchmakingSnapshot.state.focusedProfile.title\"")
            && skeletonJSON.contains("\"url\":\"cell:///ConferenceParticipantMatchmakingSnapshot\"")
        let hasDiscoverySnapshotBindings = skeletonJSON.contains("\"discoverySnapshot.state.statusSummary\"")
            && skeletonJSON.contains("\"discoverySnapshot.state.focusedProfile.title\"")
            && skeletonJSON.contains("\"url\":\"cell:///ConferenceParticipantDiscoverySnapshot\"")
        let hasNearbyDirectDispatchAction = skeletonJSON.contains("\"url\":\"cell:///ConferenceNearbyRadar\"")
            && skeletonJSON.contains("\"keypath\":\"dispatchAction\"")
        let hasNearbySnapshotReference = skeletonJSON.contains("\"nearbyRadar.snapshot\"")

        return !(hasAgendaSnapshotReference && hasAgendaSnapshotBindings && hasMatchmakingSnapshotReference && hasMatchmakingSnapshotBindings && hasDiscoverySnapshotReference && hasDiscoverySnapshotBindings && hasNearbyRadarReference && hasNearbyDirectDispatchAction && hasNearbySnapshotReference)
    }

    private static func participantPortalEndpoint(from configuration: CellConfiguration) -> String {
        let references = configuration.cellReferences ?? []
        if let labeledReference = references.first(where: { $0.label == "conferenceParticipantShell" }) {
            return labeledReference.endpoint
        }
        if let previewReference = references.first(where: {
            endpointIdentity($0.endpoint).hasSuffix("/conferenceparticipantpreviewshell")
        }) {
            return previewReference.endpoint
        }
        return "cell:///ConferenceParticipantPreviewShell"
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
