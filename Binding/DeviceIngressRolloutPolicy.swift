import Foundation

nonisolated enum BindingDeviceIngressRolloutEnvironment: String, Sendable {
    case disabled
    case staging
    case production

    var expectedOrigin: String? {
        switch self {
        case .disabled:
            return nil
        case .staging:
            return "https://staging.haven.digipomps.org"
        case .production:
            return "https://haven.digipomps.org"
        }
    }

    var expectedAudience: String? {
        switch self {
        case .disabled:
            return nil
        case .staging:
            return "staging.haven.digipomps.org"
        case .production:
            return "haven.digipomps.org"
        }
    }
}

/// Explicit release switch for the DeviceIngress transport. This is separate
/// from feature/demo catalog policy so an unrelated UI rollout can never
/// enable or disable device enrollment.
nonisolated struct BindingDeviceIngressRolloutPolicy {
    static let environmentKey = "HAVENDeviceIngressRolloutEnvironment"

    static var currentEnabled: Bool {
        #if os(iOS)
        return isEnrollmentEnabled(
            environmentText: Bundle.main.object(
                forInfoDictionaryKey: environmentKey
            ) as? String,
            platformIsIOS: true,
            configurationIsValid:
                (try? BindingDeviceIngressRuntimeConfiguration.current()) != nil
        )
        #else
        return false
        #endif
    }

    static func isEnrollmentEnabled(
        environmentText: String?,
        platformIsIOS: Bool,
        configurationIsValid: Bool
    ) -> Bool {
        guard platformIsIOS,
              configurationIsValid,
              let environment = environment(from: environmentText) else {
            return false
        }
        return environment != .disabled
    }

    static func environment(from value: String?)
        -> BindingDeviceIngressRolloutEnvironment?
    {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard normalized.isEmpty == false,
              normalized.contains("$(") == false else {
            return nil
        }
        return BindingDeviceIngressRolloutEnvironment(rawValue: normalized)
    }
}
