import Foundation
@preconcurrency import CellBase

enum LiveControlBridgeAuthorization {
    enum AuthorizationError: Error, LocalizedError {
        case contractRejected(String)

        var errorDescription: String? {
            switch self {
            case .contractRejected(let state):
                return "Local control bridge contract was not accepted (\(state))."
            }
        }
    }

    static func authorizeIfNeeded(_ emit: Emit, requester: Identity) async throws {
        let agreement = try copyAgreementTemplate(emit.agreementTemplate, appending: requester)
        let state = try await emit.addAgreement(agreement, for: requester)
        guard state == .signed else {
            throw AuthorizationError.contractRejected(state.rawValue)
        }
    }

    private static func copyAgreementTemplate(_ agreement: Agreement, appending requester: Identity) throws -> Agreement {
        let data = try JSONEncoder().encode(agreement)
        let copied = try JSONDecoder().decode(Agreement.self, from: data)
        if !copied.signatories.contains(where: { $0.uuid == requester.uuid }) {
            copied.signatories.append(requester)
        }
        return copied
    }
}
