import Foundation

/// Dyplenken fra HAVEN Agent til «Utvid entiteten» → «Ber om tilgang».
///
/// `haven://entity-extension/access-requests?contract=<kontrakt-ID>`
///
/// Lenken bare navigerer: HAVEN åpner seksjonen og markerer forespørselen.
/// Godkjenning skjer fortsatt med knappene i HAVEN. Formatet lages av
/// HavenAgentD (`HavenAccessRequestLink`); endres det der, må det endres her.
nonisolated enum BindingAccessRequestDeepLink {
    static let scheme = "haven"
    static let host = "entity-extension"
    static let path = "/access-requests"
    static let contractQueryItem = "contract"
    static let maxContractIDLength = 128
    static let maxURLLength = 512

    enum ParseResult: Equatable {
        /// Ikke denne ruten; la andre ruter prøve.
        case notThisRoute
        /// Åpne «Ber om tilgang», og marker kontrakten når den er oppgitt.
        case accepted(contractID: String?)
        /// Denne ruten, men ugyldig. Åpnes ikke.
        case rejected(String)
    }

    static func parse(_ url: URL) -> ParseResult {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == host else {
            return .notThisRoute
        }
        guard url.absoluteString.utf8.count <= maxURLLength else {
            return .rejected("url_too_long")
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.path == path,
              components.user == nil, components.password == nil, components.port == nil,
              components.fragment == nil else {
            return .rejected("unknown_path")
        }
        let items = components.queryItems ?? []
        guard items.count <= 1 else {
            return .rejected("unexpected_parameters")
        }
        guard let item = items.first else {
            return .accepted(contractID: nil)
        }
        guard item.name == contractQueryItem,
              let value = item.value,
              isValidContractID(value) else {
            return .rejected("invalid_contract")
        }
        return .accepted(contractID: value)
    }

    static func isValidContractID(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= maxContractIDLength else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            switch scalar {
            case "a"..."z", "A"..."Z", "0"..."9", "_", "-", ".", ":":
                return true
            default:
                return false
            }
        }
    }
}

/// Hvilken forespørsel «Ber om tilgang» skal markere etter at dyplenken ble åpnet.
/// Gjelder i ti minutter, så en gammel markering ikke henger igjen.
nonisolated final class BindingAccessRequestFocus: @unchecked Sendable {
    static let shared = BindingAccessRequestFocus()
    static let lifetime: TimeInterval = 10 * 60

    private let lock = NSLock()
    private var contractID: String?
    private var setAt: Date?

    func focus(contractID: String?, now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        self.contractID = contractID
        setAt = contractID == nil ? nil : now
    }

    func current(now: Date = Date()) -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard let contractID, let setAt, now.timeIntervalSince(setAt) <= Self.lifetime else {
            return nil
        }
        return contractID
    }
}
