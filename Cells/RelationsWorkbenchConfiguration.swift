// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

//
//  RelationsWorkbenchConfiguration.swift
//  Binding
//
//  One surface for the whole job.
//
//  It used to be four menu entries — Relasjoner, Hent kontakter,
//  Kontaktimport, Invitasjon — which is not four things a person wants. It is
//  three steps of one task plus the reason for doing it. Four near-synonymous
//  labels in a scrolling menu is not discoverability; it is noise.
//
//  So: one surface, one primary action, and every other section appears only
//  once it has something to say. Somebody replied → that is at the top,
//  because a person waiting beats anything else. A file is under review →
//  the review is the screen. Nobody in the list yet → one sentence and one
//  button, no empty grey boxes pretending to be content.
//
//  Two rules the panel was strict about, and this file follows:
//
//  * **Reads go through `<label>.state.…`.** A read resolves by walking down
//    from the root key, so `contactImport.import.state.x` would ask the cell
//    for a root key `import` that nobody serves — the exact shape of the
//    `perspective.perspective: notFound` bug. Writes match exactly, so they
//    keep their full action path.
//  * **No fixed list heights.** Nested scroll views break Dynamic Type and
//    push the primary action under the fold on a phone.
//

import Foundation
import CellBase

nonisolated enum HavenRelationsWorkbench {

    static let relationsEndpoint = "cell:///Relations"
    static let addressBookEndpoint = "cell:///AddressBook"
    static let importEndpoint = "cell:///ContactImport"
    static let invitationEndpoint = "cell:///Invitation"

    // MARK: - Configuration

    static func configuration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Relasjoner")
        configuration.description = "Folkene du kjenner, og veien til å invitere dem inn. Hent fra kontaktene eller en fil, finn riktig person, send invitasjonen selv."
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: relationsEndpoint,
            sourceCellName: "BindingRelationsCell",
            purpose: "Hold oversikt over relasjoner og inviter folk inn i HAVEN",
            purposeDescription: "Én flate for hele oppgaven: hent inn relasjoner, finn riktig person, lag en signert invitasjon, og ta imot svaret. Ingenting sendes uten at eieren trykker.",
            interests: BindingPersonalCopilotV1Policy.discoveryInterests(
                [
                    "relations",
                    "contacts",
                    "invite-person",
                    "contact-endpoint",
                    "onboarding",
                    "purposeRef=personal.relations.lookup",
                    "purposeRef=personal.chat.assist.invite"
                ],
                policyCategory: "invite-only-chat"
            ),
            menuSlots: ["upperRight", "lowerRight"]
        )
        configuration.addReference(CellReference(endpoint: relationsEndpoint, subscribeFeed: false, label: "relations"))
        configuration.addReference(CellReference(endpoint: addressBookEndpoint, subscribeFeed: false, label: "addressBook"))
        configuration.addReference(CellReference(endpoint: importEndpoint, subscribeFeed: false, label: "contactImport"))
        configuration.addReference(CellReference(endpoint: invitationEndpoint, subscribeFeed: false, label: "invitation"))

        configuration.skeleton = .ScrollView(SkeletonScrollView(elements: [
            .VStack(SkeletonVStack(elements: [
                header(),
                repliesSection(),
                emptyStateSection(),
                importReviewSection(),
                preparedMessageSection(),
                everydaySection(),
                outboxSection(),
                footerSection()
            ], spacing: 18))
        ]))
        return configuration
    }

    // MARK: - Sections

    private static func header() -> SkeletonElement {
        var title = SkeletonText(text: "Relasjoner")
        title.modifiers = style { $0.fontStyle = "title2"; $0.fontWeight = "semibold" }
        var summary = SkeletonText(keypath: "relations.state.summary")
        summary.modifiers = style { $0.foregroundColor = "#475569" }
        return .VStack(SkeletonVStack(elements: [.Text(title), .Text(summary)], spacing: 4))
    }

    /// Someone answered an invitation. Nothing else on this screen matters more,
    /// so it sits above everything and disappears the moment it is empty.
    private static func repliesSection() -> SkeletonElement {
        var row = SkeletonVStack(elements: [
            .Text(bold(keypath: "displayName")),
            .Text(SkeletonText(keypath: "statusLine")),
            .Text(SkeletonText(keypath: "message")),
            .Button(SkeletonButton(
                keypath: "invitation.invite.acceptContactRequest",
                label: "Legg til som kontakt",
                payloadKeypath: "requestID"
            ))
        ], spacing: 4)
        row.modifiers = card(borderColor: "#16A34A")

        var section = SkeletonVStack(elements: [
            .Text(sectionTitle("Noen har svart")),
            .List(SkeletonList(topic: nil, keypath: "invitation.state.inbox", flowElementSkeleton: row))
        ], spacing: 8)
        section.modifiers = visible(
            when: SkeletonCondition(
                scope: .root,
                keypath: "invitation.state.pendingReplyCount",
                notEquals: .integer(0)
            )
        )
        return .VStack(section)
    }

    /// First run. One sentence about what happens, one about what does not,
    /// and two ways in. No lists — an empty list is not an onboarding.
    private static func emptyStateSection() -> SkeletonElement {
        var lead = SkeletonText(text: "Hent inn folkene du kjenner, så kan du invitere dem herfra.")
        lead.modifiers = style { $0.fontStyle = "headline" }

        var boundary = SkeletonText(text: "Jeg leser bare de du selv peker på, og alt blir liggende på denne enheten. Ingenting sendes før du trykker send.")
        boundary.modifiers = style { $0.foregroundColor = "#475569" }

        var section = SkeletonVStack(elements: [
            .Text(lead),
            .Text(boundary),
            .Button(SkeletonButton(
                keypath: "addressBook.addressBook.pickContacts",
                label: "Velg fra kontaktene",
                payload: .object([:])
            )),
            .Button(SkeletonButton(
                keypath: "addressBook.addressBook.pickFile",
                label: "Hent fra en fil",
                payload: .object([:])
            )),
            .Text(subtle(keypath: "addressBook.state.permission.recommendedAction"))
        ], spacing: 10)
        section.modifiers = visible(
            when: SkeletonCondition(
                scope: .root,
                keypath: "relations.state.stats.total",
                equals: .integer(0)
            )
        )
        return .VStack(section)
    }

    /// A file is waiting for a decision. While that is true, the review *is*
    /// the screen — showing the everyday list underneath would invite the
    /// person to wander off mid-task.
    private static func importReviewSection() -> SkeletonElement {
        // One row per column: what it is called, what we think it holds, and
        // a picker to say otherwise. The column index never appears.
        var columnRow = SkeletonVStack(elements: [
            .Text(bold(keypath: "header")),
            .Picker(SkeletonPicker(
                label: nil,
                placeholder: "Velg hva kolonnen er",
                keypath: "fieldOptions",
                optionLabelKeypath: "label",
                selectionValueKeypath: "value",
                selectionStateKeypath: "field",
                selectionActionKeypath: "contactImport.import.setMapping",
                selectionPayloadMode: .item
            )),
            .Text(subtle(keypath: "sampleText"))
        ], spacing: 4)
        columnRow.modifiers = card(borderColor: "#CBD5E1")

        var personRow = SkeletonVStack(elements: [
            .Text(bold(keypath: "displayName")),
            .Text(subtle(keypath: "subtitle"))
        ], spacing: 2)
        personRow.modifiers = card(borderColor: "#E2E8F0")

        var uncertain = SkeletonText(keypath: "contactImport.state.preview.uncertainSummary")
        uncertain.modifiers = style { $0.foregroundColor = "#B45309" }

        var section = SkeletonVStack(elements: [
            .Text(sectionTitle("Se over før du legger dem inn")),
            .Text(SkeletonText(keypath: "contactImport.state.summary")),
            .Text(subtle(keypath: "contactImport.state.preview.consentLine")),
            .Text(uncertain),
            .List(SkeletonList(topic: nil, keypath: "contactImport.state.preview.reviewColumns", flowElementSkeleton: columnRow)),
            .TextField(SkeletonTextField(
                text: nil,
                sourceKeypath: "contactImport.state.preview.context",
                targetKeypath: "contactImport.import.setContext",
                placeholder: "Hva er dette? F.eks. «Bok: Rammebetingelser for innovasjon»"
            )),
            .Text(subtle(keypath: "contactImport.state.preview.contextHint")),
            .Text(sectionTitle("Slik blir de seende ut")),
            .List(SkeletonList(topic: nil, keypath: "contactImport.state.preview.rows", flowElementSkeleton: personRow)),
            .HStack(SkeletonHStack(elements: [
                .Button(SkeletonButton(
                    keypath: "contactImport.import.commit",
                    label: "Legg dem inn",
                    payload: .object([:])
                )),
                .Button(SkeletonButton(
                    keypath: "contactImport.import.discard",
                    label: "Forkast",
                    payload: .object([:])
                ))
            ], spacing: 10))
        ], spacing: 10)
        section.modifiers = visible(
            when: SkeletonCondition(
                scope: .root,
                keypath: "contactImport.state.hasPending",
                equals: .bool(true)
            )
        )
        return .VStack(section)
    }

    /// The finished message, and the button that actually opens it. Before this
    /// existed the person was left holding a ready invitation they could not
    /// act on.
    private static func preparedMessageSection() -> SkeletonElement {
        var body = SkeletonText(keypath: "invitation.state.lastResult.body")
        body.modifiers = style { $0.foregroundColor = "#334155"; $0.lineLimit = 6 }

        var section = SkeletonVStack(elements: [
            .Text(sectionTitle("Klar til å sendes")),
            .Text(SkeletonText(keypath: "invitation.state.lastResult.message")),
            .Text(body),
            .Button(SkeletonButton(
                keypath: "invitation.invite.openPreparedMessage",
                label: "Åpne meldingen",
                payloadKeypath: "invitation.state.lastResult.ticketID"
            )),
            .Text(subtle(keypath: "invitation.state.lastResult.boundaryStatement")),
            .Text(subtle(keypath: "invitation.state.lastResult.publicationWarning"))
        ], spacing: 8)
        section.modifiers = card(borderColor: "#2563EB")
        section.modifiers?.visibility = SkeletonVisibilityRule(
            when: SkeletonCondition(
                scope: .root,
                keypath: "invitation.state.lastResult.handoffURL",
                notEquals: .string("")
            )
        )
        return .VStack(section)
    }

    /// The everyday shape once there is something to work with: one search
    /// field, the people it found, and an invite button on each of them.
    private static func everydaySection() -> SkeletonElement {
        var row = SkeletonVStack(elements: [
            .Text(bold(keypath: "displayName")),
            .Text(subtle(keypath: "subtitle")),
            .Text(subtle(keypath: "endpointSummary")),
            .Button(SkeletonButton(
                keypath: "invitation.invite.prepare",
                label: "Inviter",
                payloadKeypath: "id"
            )),
            .Text(subtle(keypath: "inviteBlockReason"))
        ], spacing: 4)
        row.modifiers = card(borderColor: "#CBD5E1")

        var section = SkeletonVStack(elements: [
            .TextField(SkeletonTextField(
                targetKeypath: "relations.relations.search",
                placeholder: "Hvem leter du etter?"
            )),
            .Text(SkeletonText(keypath: "relations.state.lastSearch.summaryText")),
            .Text(SkeletonText(keypath: "relations.state.lastSearch.clarifyingQuestion")),
            .List(SkeletonList(topic: nil, keypath: "relations.state.shortlist", flowElementSkeleton: row)),
            .Text(subtle(keypath: "relations.state.shortlistNote")),
            .HStack(SkeletonHStack(elements: [
                .Button(SkeletonButton(
                    keypath: "addressBook.addressBook.pickContacts",
                    label: "Hent flere fra kontaktene",
                    payload: .object([:])
                )),
                .Button(SkeletonButton(
                    keypath: "addressBook.addressBook.pickFile",
                    label: "Hent fra en fil",
                    payload: .object([:])
                ))
            ], spacing: 10))
        ], spacing: 10)
        section.modifiers = visible(
            when: SkeletonCondition(
                scope: .root,
                keypath: "relations.state.stats.total",
                notEquals: .integer(0)
            )
        )
        return .VStack(section)
    }

    /// What has gone out, and what came back. Two honest buttons: one asks the
    /// scaffold for status, one collects replies. Neither sends anything.
    private static func outboxSection() -> SkeletonElement {
        var row = SkeletonVStack(elements: [
            .Text(bold(keypath: "displayName")),
            .Text(subtle(keypath: "statusLine")),
            .Text(subtle(keypath: "humanCode"))
        ], spacing: 3)
        row.modifiers = card(borderColor: "#E2E8F0")

        var section = SkeletonVStack(elements: [
            .Divider(SkeletonDivider()),
            .Text(sectionTitle("Invitasjoner")),
            .List(SkeletonList(topic: nil, keypath: "invitation.state.outbox", flowElementSkeleton: row)),
            .HStack(SkeletonHStack(elements: [
                .Button(SkeletonButton(
                    keypath: "invitation.invite.refreshStatus",
                    label: "Sjekk status",
                    payload: .object([:])
                )),
                .Button(SkeletonButton(
                    keypath: "invitation.invite.pullContactRequests",
                    label: "Hent svar",
                    payload: .object([:])
                ))
            ], spacing: 10))
        ], spacing: 8)
        section.modifiers = visible(
            when: SkeletonCondition(
                scope: .root,
                keypath: "invitation.state.counts.total",
                notEquals: .integer(0)
            )
        )
        return .VStack(section)
    }

    private static func footerSection() -> SkeletonElement {
        var warning = SkeletonText(keypath: "invitation.state.settings.scaffoldWarning")
        warning.modifiers = style { $0.foregroundColor = "#B45309" }
        warning.modifiers?.visibility = SkeletonVisibilityRule(
            when: SkeletonCondition(
                scope: .root,
                keypath: "invitation.state.settings.scaffoldWarning",
                notEquals: .string("")
            )
        )

        var result = SkeletonText(keypath: "relations.state.lastMutation.message")
        result.modifiers = style { $0.foregroundColor = "#475569" }

        return .VStack(SkeletonVStack(elements: [
            .Text(warning),
            .Text(result),
            .Text(subtle(keypath: "invitation.state.boundaryStatement"))
        ], spacing: 6))
    }

    // MARK: - Small style helpers

    private static func style(_ configure: (inout SkeletonModifiers) -> Void) -> SkeletonModifiers {
        var modifiers = SkeletonModifiers()
        configure(&modifiers)
        return modifiers
    }

    private static func card(borderColor: String) -> SkeletonModifiers {
        style {
            $0.padding = 12
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = borderColor
            $0.maxWidthInfinity = true
            $0.styleRole = "personal-list-row"
        }
    }

    private static func visible(when condition: SkeletonCondition) -> SkeletonModifiers {
        style { $0.visibility = SkeletonVisibilityRule(when: condition) }
    }

    private static func sectionTitle(_ text: String) -> SkeletonText {
        var element = SkeletonText(text: text)
        element.modifiers = style { $0.fontStyle = "headline" }
        return element
    }

    private static func bold(keypath: String) -> SkeletonText {
        var element = SkeletonText(keypath: keypath)
        element.modifiers = style { $0.fontWeight = "semibold" }
        return element
    }

    private static func subtle(keypath: String) -> SkeletonText {
        var element = SkeletonText(keypath: keypath)
        element.modifiers = style { $0.foregroundColor = "#64748B" }
        return element
    }
}
