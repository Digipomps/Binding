// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Testing
import CellBase
@testable import Binding

/// The identity the app boots with used to be minted fresh per launch, so the
/// cell container every `.identityUnique` cell wrote into was never opened
/// again. Two vaults over one store stand in for two launches of one app.
@Suite struct BindingStartupIdentityVaultTests {

    @Test func theSamePersonComesBackOnTheNextLaunch() async throws {
        let store = BindingInMemoryStartupIdentityStore()
        let firstLaunch = BindingStartupIdentityVault(durable: true, store: store)
        let secondLaunch = BindingStartupIdentityVault(durable: true, store: store)

        let first = try #require(await firstLaunch.identity(for: "private", makeNewIfNotFound: true))
        let second = try #require(await secondLaunch.identity(for: "private", makeNewIfNotFound: true))

        #expect(first.uuid == second.uuid)
        #expect(first.signingPublicKeyFingerprint == second.signingPublicKeyFingerprint)
        #expect(first.homeVaultReference == second.homeVaultReference)
    }

    /// Same UUID is not enough — the private key has to come back too, or the
    /// restored identity cannot sign for the data it wrote.
    @Test func theRestoredIdentityStillHoldsItsOwnPrivateKey() async throws {
        let store = BindingInMemoryStartupIdentityStore()
        let firstLaunch = BindingStartupIdentityVault(durable: true, store: store)
        let first = try #require(await firstLaunch.identity(for: "private", makeNewIfNotFound: true))
        let message = Data("bevis på kontakt".utf8)
        let signature = try await firstLaunch.signMessageForIdentity(messageData: message, identity: first)

        let secondLaunch = BindingStartupIdentityVault(durable: true, store: store)
        let second = try #require(await secondLaunch.identity(for: "private", makeNewIfNotFound: true))
        let verified = try await secondLaunch.verifySignature(signature: signature, messageData: message, for: second)
        #expect(verified)

        let resigned = try await secondLaunch.signMessageForIdentity(messageData: message, identity: second)
        #expect(try await firstLaunch.verifySignature(signature: resigned, messageData: message, for: first))
    }

    /// A launch that adds its own default identity for a context must adopt
    /// the stored one, not overwrite the keys and orphan the data.
    @Test func addingADefaultIdentityAdoptsTheStoredOneInsteadOfMintingOver() async throws {
        let store = BindingInMemoryStartupIdentityStore()
        let firstLaunch = BindingStartupIdentityVault(durable: true, store: store)
        let first = try #require(await firstLaunch.identity(for: "private", makeNewIfNotFound: true))

        let secondLaunch = BindingStartupIdentityVault(durable: true, store: store)
        var offered = Identity()
        offered.displayName = "HAVEN Local Session"
        await secondLaunch.addIdentity(identity: &offered, for: "private")

        #expect(offered.uuid == first.uuid)
    }

    @Test func anEphemeralVaultForgetsOnPurpose() async throws {
        let store = BindingInMemoryStartupIdentityStore()
        let firstLaunch = BindingStartupIdentityVault(durable: false, store: store)
        let secondLaunch = BindingStartupIdentityVault(durable: false, store: store)
        let first = try #require(await firstLaunch.identity(for: "private", makeNewIfNotFound: true))
        let second = try #require(await secondLaunch.identity(for: "private", makeNewIfNotFound: true))
        #expect(first.uuid != second.uuid)
    }

    @Test func testsAndExplicitFlagsStayEphemeral() {
        #expect(!BindingStartupIdentityVault.shouldPersistAcrossLaunches(
            environment: ["XCTestConfigurationFilePath": "/x"], launchArguments: []))
        #expect(!BindingStartupIdentityVault.shouldPersistAcrossLaunches(
            environment: [:], launchArguments: ["--haven-ephemeral-identity"]))
        #expect(!BindingStartupIdentityVault.shouldPersistAcrossLaunches(
            environment: ["HAVEN_EPHEMERAL_IDENTITY": "1"], launchArguments: []))
        #expect(BindingStartupIdentityVault.shouldPersistAcrossLaunches(
            environment: [:], launchArguments: []))
    }
}
