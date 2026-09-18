// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Testing
import Foundation
@testable import Binding

/// The butler finds a surface by what the surface says about itself. These
/// pin the words-to-words part: Norwegian spelled three ways still meets,
/// the right surface wins among neighbours, and a thin description is
/// called thin.
@Suite struct HavenSurfaceRelevanceTests {

    private let relations = HavenSurfaceDescriptor(
        name: "Relations Workbench",
        displayName: "Relasjoner",
        purpose: "Kontakt og kommunikasjon",
        purposeDescription: "Hent inn folk fra adresseboka eller en fil, se hvem som er i HAVEN og hvem som mangler kanal, og send invitasjoner du selv trykker send på.",
        summary: "Dine relasjoner: import, dedupe, invitasjon.",
        tags: ["relasjoner", "kontakter", "invitasjon"],
        interests: ["relations", "contacts", "invite", "import"],
        sourceCellEndpoint: "cell:///Relations"
    )
    private let scanner = HavenSurfaceDescriptor(
        name: "Entity Scanner",
        displayName: "Entity Scanner",
        purpose: "Nærhet",
        purposeDescription: "Oppdag andre HAVEN-enheter i nærheten som en radar, be om kontakt, signer møtet og eksporter bevis som JSON.",
        summary: "Radar for enheter i nærheten.",
        tags: ["nearby", "radar", "scanner"],
        interests: ["nearby", "bluetooth", "proof"],
        sourceCellEndpoint: "cell:///EntityScanner"
    )
    private let vault = HavenSurfaceDescriptor(
        name: "Vault",
        displayName: "Vault / Ideas",
        purpose: "Notater",
        purposeDescription: "Lokal Obsidian-lignende vault for ideer, prosjektnotater og markdown med graf over lenkene mellom dem.",
        summary: "Notater og ideer, lokalt.",
        tags: ["vault", "notater", "markdown"],
        interests: ["ideas", "notes", "graph"],
        sourceCellEndpoint: "cell:///Vault"
    )

    @Test func norwegianSpelledThreeWaysMeetsInTheMiddle() {
        #expect(HavenSurfaceRelevance.normalize("håndter påminnelser") == HavenSurfaceRelevance.normalize("haandter paaminnelser"))
        #expect(HavenSurfaceRelevance.normalize("oppfølging") == HavenSurfaceRelevance.normalize("oppfoelging"))
        #expect(HavenSurfaceRelevance.tokens("Relasjonene mine") == ["relas"])
    }

    @Test func thePromptFindsTheSurfaceThatDescribesIt() {
        let all = [relations, scanner, vault]
        #expect(HavenSurfaceRelevance.rank(prompt: "hvem i nærheten kan jeg be om kontakt", descriptors: all).first?.descriptor.name == "Entity Scanner")
        #expect(HavenSurfaceRelevance.rank(prompt: "inviter folk fra adresseboka", descriptors: all).first?.descriptor.name == "Relations Workbench")
        #expect(HavenSurfaceRelevance.rank(prompt: "prosjektnotater i markdown", descriptors: all).first?.descriptor.name == "Vault")
        #expect(HavenSurfaceRelevance.rank(prompt: "hva er klokka", descriptors: all).isEmpty)
    }

    @Test func aThinDescriptionIsNamedAsThin() {
        var thin = vault
        thin.purposeDescription = "Vis og forvalt vault."
        thin.tags = []
        thin.interests = ["vault"]
        thin.summary = nil
        let kinds = Set(HavenSurfaceRelevance.audit(thin).map(\.kind))
        #expect(kinds.contains(.purposeDescriptionTooShort))
        #expect(kinds.contains(.purposeDescriptionRestatesName))
        #expect(kinds.contains(.tooFewInterests))
        #expect(kinds.contains(.missingSummary))
        #expect(HavenSurfaceRelevance.audit(vault).isEmpty)
    }

    @Test func transliterationIsCaughtOnlyWhenTheTextHasNoRealLetters() {
        #expect(HavenSurfaceRelevance.transliteratedWord(in: "Haandter utstiller- og messeadgang.") == "haandter")
        #expect(HavenSurfaceRelevance.transliteratedWord(in: "Håndter utstiller- og messeadgang paa stand.") == nil)
        #expect(HavenSurfaceRelevance.transliteratedWord(in: "It does what it says.") == nil)
    }

    @Test func aSurfaceIsFoundByItsOwnDescriptionWithoutItsName() {
        let all = [relations, scanner, vault]
        for descriptor in all {
            let probe = HavenSurfaceRelevance.findabilityProbe(for: descriptor)
            let firstWord = HavenSurfaceRelevance.normalize(descriptor.name.split(separator: " ").first.map(String.init) ?? "")
            #expect(!probe.contains(firstWord), Comment(rawValue: "probe leaks the name: \(probe)"))
            #expect(HavenSurfaceRelevance.rank(prompt: probe, descriptors: all).first?.descriptor.name == descriptor.name, Comment(rawValue: probe))
        }
    }
}
