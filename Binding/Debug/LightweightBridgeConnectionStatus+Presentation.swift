import SwiftUI
import CellBase

extension LightweightBridgeConnectionStatus {
    var severityRank: Int {
        switch phase {
        case .failed:
            return 5
        case .disconnected:
            return 4
        case .reconnecting:
            return 3
        case .connecting:
            return 2
        case .connected:
            return 1
        }
    }

    func shouldDisplay(relativeTo now: Date) -> Bool {
        let age = now.timeIntervalSince(updatedAt)
        switch phase {
        case .connected:
            return age <= 10
        case .connecting:
            return age <= 20
        case .reconnecting, .disconnected, .failed:
            return age <= 90
        }
    }

    func isExpired(relativeTo now: Date) -> Bool {
        let age = now.timeIntervalSince(updatedAt)
        switch phase {
        case .connected:
            return age > 20
        case .connecting:
            return age > 40
        case .reconnecting, .disconnected, .failed:
            return age > 180
        }
    }

    var titleText: String {
        switch phase {
        case .connecting:
            return "Kobler til bridge"
        case .connected:
            return "Bridge tilkoblet"
        case .reconnecting:
            return "Kobler til igjen"
        case .disconnected:
            return "Bridge frakoblet"
        case .failed:
            return "Bridge-feil"
        }
    }

    var subtitleText: String {
        var parts: [String] = [endpointSummary]
        if let attempt {
            parts.append("forsøk \(attempt)")
        }
        if let detail, !detail.isEmpty {
            parts.append(detail)
        }
        return parts.joined(separator: " • ")
    }

    var tintColor: Color {
        switch phase {
        case .connecting:
            return .blue
        case .connected:
            return .green
        case .reconnecting:
            return .orange
        case .disconnected:
            return .orange
        case .failed:
            return .red
        }
    }

    var iconName: String {
        switch phase {
        case .connecting:
            return "bolt.horizontal.circle.fill"
        case .connected:
            return "checkmark.circle.fill"
        case .reconnecting:
            return "arrow.trianglehead.2.clockwise.rotate.90.circle.fill"
        case .disconnected:
            return "wifi.slash"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    var endpointSummary: String {
        guard let components = URLComponents(string: endpoint) else {
            return endpoint
        }

        let host = components.host ?? endpoint
        let lastPath = components.path
            .split(separator: "/")
            .last
            .map(String.init)

        if let lastPath, !lastPath.isEmpty, lastPath.lowercased() != host.lowercased() {
            return "\(host)/\(lastPath)"
        }

        return host
    }
}
