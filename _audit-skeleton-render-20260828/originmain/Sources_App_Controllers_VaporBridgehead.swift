// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

//
//  File.swift
//  
//
//  Created by Kjetil Hustveit on 14/11/2023.
//

import Foundation
import CellBase

// Conference preview identity helpers retained for their focused contract tests.
// No web route is registered here; the old unauthenticated bridgehead is removed.
struct VaporBridgehead {
    struct BridgeDescriptor {
        let targetPublisherReference: String
        let identityDomain: String
    }

    private static let participantPreviewBridgeIDs: Set<String> = [
        "ConferenceParticipantShell",
        "ConferenceParticipantPreviewShell",
        "ConferenceAIGatewayPreview",
        "ConferencePublicProfilePreview",
        "ConferencePublicProfileEditorPreview"
    ]

    private static let organizerBridgeIDs: Set<String> = [
        "ConferenceUIRouter",
        "ConferenceAdminShell"
    ]

    private static let adminPreviewBridgeIDs: Set<String> = [
        "ConferenceAdminPreviewShell"
    ]

    private static let sponsorPreviewBridgeIDs: Set<String> = [
        "ConferenceSponsorPreviewShell"
    ]

    private static func shouldResetPreviewMappings(for bridgeReference: String) -> Bool {
        participantPreviewBridgeIDs.contains(bridgeReference)
            || adminPreviewBridgeIDs.contains(bridgeReference)
            || sponsorPreviewBridgeIDs.contains(bridgeReference)
    }
    
    static func bridgeConfig(
        publisherIdentity: Identity,
        publisherReference: String,
        bridgeReference: String,
        transport: BridgeTransportProtocol
    ) async -> BridgeBase.Config {
        let descriptor = bridgeDescriptor(
            requester: publisherIdentity,
            publisherReference: publisherReference,
            bridgeReference: bridgeReference
        )
        return BridgeBase.Config(
            owner: publisherIdentity,
            contractTemplate: Agreement(owner: publisherIdentity),
            identityDomain: descriptor.identityDomain,
            transport: transport,
            connection: .inbound(publisherUuid: descriptor.targetPublisherReference),
            // Keep requester commands as requester commands, but resolve the local
            // identity-scoped publisher through this bridgehead route identity.
            inboundPublisherLookupIdentity: publisherIdentity
        )
    }

    static func bridgeDescriptor(
        requester: Identity,
        publisherReference: String,
        bridgeReference: String
    ) -> BridgeDescriptor {
        BridgeDescriptor(
            targetPublisherReference: publisherReference,
            identityDomain: "bridgehead:\(bridgeReference):\(requester.uuid)"
        )
    }

    func identityForBridgeReference(_ bridgeReference: String) async throws -> (Identity, CellResolverProtocol, IdentityVaultProtocol) {
       guard let resolver = CellBase.defaultCellResolver else {
           throw CellBaseError.noResolver
       }
       guard let vault = CellBase.defaultIdentityVault else {
           throw CellBaseError.noVault
       }

       let requester: Identity
       if Self.participantPreviewBridgeIDs.contains(bridgeReference) {
           requester = try await ConferenceParticipantPreviewIdentity.resolve(
               previewParticipantId: ConferenceParticipantPreviewIdentity.defaultPreviewParticipantId,
               preferredVault: vault
           )
       } else if Self.organizerBridgeIDs.contains(bridgeReference) {
           requester = try await ConferenceOrganizerIdentity.resolve(
               preferredVault: vault,
               displayName: ConferenceOrganizerIdentity.ownerDisplayName
           )
       } else if Self.adminPreviewBridgeIDs.contains(bridgeReference) {
           requester = try await ConferenceAdminPreviewIdentity.resolve(
               previewAdminId: ConferenceAdminPreviewIdentity.defaultPreviewAdminId
           )
       } else if Self.sponsorPreviewBridgeIDs.contains(bridgeReference) {
           requester = try await ConferenceSponsorPreviewIdentity.resolve(
               sponsorOrganizationId: ConferenceSponsorIdentity.defaultSponsorOrganizationId
           )
       } else if let scaffold = await vault.identity(for: "Scaffold", makeNewIfNotFound: false) {
           requester = scaffold
       } else {
           throw CellBaseError.noIdentity
       }
       if Self.shouldResetPreviewMappings(for: bridgeReference) {
           _ = await ConferencePreviewWrapperResolverSupport.resetStalePreviewMappingsIfNeeded(
               for: "cell:///\(bridgeReference)",
               requester: requester
           )
       }
       return (requester, resolver, vault)
   }

}
