// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

//
//  ContactSourceBridge.swift
//  Binding
//
//  The only place in HAVEN that touches the system address book or opens a
//  file picker.
//
//  The default path is the system contact picker: it shows the user their own
//  contacts, returns only the ones they point at, and asks for no permission
//  at all — the OS mediates. Full address book access exists too, but behind
//  its own deliberate step, because "let me read all your contacts" is a much
//  bigger question than "pick three people".
//

import Foundation
#if canImport(Contacts)
import Contacts
#endif
#if canImport(ContactsUI)
import ContactsUI
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

// MARK: - Neutral shapes

/// One reachable address as the address book reported it. Normalisation
/// happens later, in the relations layer, so the raw value survives.
nonisolated struct BindingContactChannel: Sendable, Equatable {
    var value: String
    var label: String?

    init(value: String, label: String? = nil) {
        self.value = value
        self.label = label
    }
}

/// Handed to the cells so nothing downstream knows about `CNContact`. Matches
/// the loose contact shape `relations.upsert` accepts.
nonisolated struct BindingContactCandidate: Sendable, Equatable {
    var identifier: String
    var givenName: String?
    var familyName: String?
    var displayName: String?
    var organization: String?
    var jobTitle: String?
    var emails: [BindingContactChannel] = []
    var phones: [BindingContactChannel] = []
    var urls: [String] = []
    var notes: String?
    var groups: [String] = []

    /// The `Object` shape `relations.upsert` reads under `contacts`.
    var contactObject: [String: Any] {
        var object: [String: Any] = ["sourceIdentifier": identifier]
        if let givenName { object["givenName"] = givenName }
        if let familyName { object["familyName"] = familyName }
        if let displayName { object["displayName"] = displayName }
        if let organization { object["organization"] = organization }
        if let jobTitle { object["jobTitle"] = jobTitle }
        if let notes { object["notes"] = notes }
        if !emails.isEmpty { object["emails"] = emails.map(Self.channelObject) }
        if !phones.isEmpty { object["phones"] = phones.map(Self.channelObject) }
        if !urls.isEmpty { object["urls"] = urls }
        if !groups.isEmpty { object["groups"] = groups }
        return object
    }

    private static func channelObject(_ channel: BindingContactChannel) -> [String: String] {
        var value = ["value": channel.value]
        if let label = channel.label { value["label"] = label }
        return value
    }
}

nonisolated enum BindingContactAccessState: String, Sendable {
    case notDetermined
    case denied
    case restricted
    case limited
    case authorized
    case unavailable

    var isReadable: Bool { self == .authorized || self == .limited }

    var explanation: String {
        switch self {
        case .notDetermined:
            return "Jeg har ikke spurt om kontakttilgang. Du kan velge enkeltpersoner uten å gi tilgang i det hele tatt."
        case .denied:
            return "Full kontakttilgang er avslått. Du kan fortsatt velge enkeltpersoner via kontaktvelgeren."
        case .restricted:
            return "Enheten tillater ikke kontakttilgang. Kontaktvelgeren og filimport virker likevel."
        case .limited:
            return "Jeg ser bare kontaktene du har valgt ut."
        case .authorized:
            return "Jeg kan lese hele kontaktlisten din. Du kan trekke det tilbake i Systeminnstillinger når som helst."
        case .unavailable:
            return "Kontakter er ikke tilgjengelig på denne plattformen. Bruk filimport i stedet."
        }
    }
}

nonisolated enum BindingContactSourceError: Error, Sendable, CustomStringConvertible {
    case notAuthorized(BindingContactAccessState)
    case unsupportedPlatform
    case noPresenter
    case cancelled
    case fetchFailed(String)

    var code: String {
        switch self {
        case .notAuthorized: return "not_authorized"
        case .unsupportedPlatform: return "unsupported_platform"
        case .noPresenter: return "no_presenter"
        case .cancelled: return "cancelled"
        case .fetchFailed: return "fetch_failed"
        }
    }

    var description: String {
        switch self {
        case .notAuthorized(let state): return state.explanation
        case .unsupportedPlatform:
            return "Kontaktvelgeren finnes ikke på denne plattformen. Gi full kontakttilgang, eller importer en fil."
        case .noPresenter: return "Fant ingen vindu å vise velgeren i."
        case .cancelled: return "Avbrutt."
        case .fetchFailed(let detail): return detail
        }
    }
}

nonisolated struct BindingPickedFile: Sendable {
    var filename: String
    var data: Data
    var mimeType: String?
}

// MARK: - Bridge

@MainActor
final class BindingContactSourceBridge {

    static let shared = BindingContactSourceBridge()

    private init() {}

    /// Keeps the active picker's delegate alive for the duration of the
    /// presentation. One picker at a time is the whole story here.
    private var activeCoordinator: AnyObject?

    // MARK: Authorisation

    var accessState: BindingContactAccessState {
#if canImport(Contacts)
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .authorized
        case .limited: return .limited
        @unknown default: return .limited
        }
#else
        return .unavailable
#endif
    }

    /// Only reached when the user explicitly asks for a full import. The
    /// picker path never calls this.
    func requestFullAccess() async -> BindingContactAccessState {
#if canImport(Contacts)
        if accessState.isReadable { return accessState }
        let store = CNContactStore()
        _ = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            store.requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
        return accessState
#else
        return .unavailable
#endif
    }

    // MARK: Picker

    /// Whether a system contact picker exists here. macOS has no picker we can
    /// drive from a cell, so that platform falls back to the permissioned path
    /// and the surface says so rather than showing a dead button.
    var supportsPicker: Bool {
#if os(iOS) || os(visionOS)
        return true
#else
        return false
#endif
    }

    /// Presents the OS contact picker and returns only what the user chose.
    /// No permission dialog is involved — the picker itself is the consent.
    func pickContacts() async -> Result<[BindingContactCandidate], BindingContactSourceError> {
#if (os(iOS) || os(visionOS)) && canImport(ContactsUI)
        guard let presenter = Self.topViewController() else { return .failure(.noPresenter) }
        let picked: [BindingContactCandidate] = await withCheckedContinuation { continuation in
            let coordinator = BindingContactPickerCoordinator { [weak self] contacts in
                self?.activeCoordinator = nil
                continuation.resume(returning: contacts)
            }
            activeCoordinator = coordinator
            let picker = CNContactPickerViewController()
            picker.delegate = coordinator
            presenter.present(picker, animated: true)
        }
        return .success(picked)
#else
        return .failure(.unsupportedPlatform)
#endif
    }

    // MARK: Full scan

    /// Reads the whole address book. Requires access the user granted in a
    /// separate, explicit step.
    func fetchAllContacts(limit: Int = 5000) async -> Result<[BindingContactCandidate], BindingContactSourceError> {
#if canImport(Contacts)
        guard accessState.isReadable else { return .failure(.notAuthorized(accessState)) }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // A fresh store inside the background context: `CNContactStore`
                // is not safe to hand across isolation domains.
                let store = CNContactStore()
                var candidates: [BindingContactCandidate] = []
                let request = CNContactFetchRequest(keysToFetch: BindingContactConversion.fetchKeys)
                request.sortOrder = .familyName
                do {
                    try store.enumerateContacts(with: request) { contact, stop in
                        candidates.append(BindingContactConversion.candidate(from: contact))
                        if candidates.count >= limit { stop.pointee = true }
                    }
                    continuation.resume(returning: .success(candidates))
                } catch {
                    continuation.resume(returning: .failure(.fetchFailed(
                        "Kunne ikke lese kontaktene: \(error.localizedDescription)"
                    )))
                }
            }
        }
#else
        return .failure(.unsupportedPlatform)
#endif
    }

    // MARK: File picking

    /// Opens the system file picker for the formats the import cell can read.
    func pickContactFile() async -> Result<BindingPickedFile, BindingContactSourceError> {
#if os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Velg en kontaktfil (CSV, Excel eller vCard)"
#if canImport(UniformTypeIdentifiers)
        panel.allowedContentTypes = Self.allowedContentTypes()
#endif
        let response = await withCheckedContinuation { (continuation: CheckedContinuation<NSApplication.ModalResponse, Never>) in
            panel.begin { continuation.resume(returning: $0) }
        }
        guard response == .OK, let url = panel.url else { return .failure(.cancelled) }
        return Self.read(url: url)
#elseif os(iOS) || os(visionOS)
        guard let presenter = Self.topViewController() else { return .failure(.noPresenter) }
        let url: URL? = await withCheckedContinuation { continuation in
            let coordinator = BindingDocumentPickerCoordinator { [weak self] picked in
                self?.activeCoordinator = nil
                continuation.resume(returning: picked)
            }
            activeCoordinator = coordinator
            let picker = UIDocumentPickerViewController(
                forOpeningContentTypes: Self.allowedContentTypes(),
                asCopy: true
            )
            picker.delegate = coordinator
            picker.allowsMultipleSelection = false
            presenter.present(picker, animated: true)
        }
        guard let url else { return .failure(.cancelled) }
        return Self.read(url: url)
#else
        return .failure(.unsupportedPlatform)
#endif
    }

    private static func read(url: URL) -> Result<BindingPickedFile, BindingContactSourceError> {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            return .success(BindingPickedFile(filename: url.lastPathComponent, data: data, mimeType: nil))
        } catch {
            return .failure(.fetchFailed("Kunne ikke lese \(url.lastPathComponent): \(error.localizedDescription)"))
        }
    }

#if canImport(UniformTypeIdentifiers)
    private static func allowedContentTypes() -> [UTType] {
        var types: [UTType] = []
        if let vcard = UTType("public.vcard") { types.append(vcard) }
        if let xlsx = UTType("org.openxmlformats.spreadsheetml.sheet") { types.append(xlsx) }
        types.append(contentsOf: [.commaSeparatedText, .tabSeparatedText, .plainText, .text])
        // Listed so the picker does not grey out Numbers files; the import cell
        // recognises them and explains how to export instead of failing blankly.
        if let numbers = UTType("com.apple.iwork.numbers.numbers") { types.append(numbers) }
        return types
    }
#endif

    // MARK: Presentation lookup

#if os(iOS) || os(visionOS)
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let active = scenes.filter { $0.activationState == .foregroundActive }
        let windows = (active.isEmpty ? scenes : active).flatMap(\.windows)
        var controller = (windows.first(where: \.isKeyWindow) ?? windows.first)?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
#endif
}

// MARK: - Conversion

nonisolated enum BindingContactConversion {
#if canImport(Contacts)
    nonisolated static let fetchKeys: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactJobTitleKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactUrlAddressesKey as CNKeyDescriptor,
        CNContactIdentifierKey as CNKeyDescriptor
    ]

    nonisolated static func candidate(from contact: CNContact) -> BindingContactCandidate {
        let emails = contact.emailAddresses.map { entry in
            BindingContactChannel(
                value: entry.value as String,
                label: entry.label.map { CNLabeledValue<NSString>.localizedString(forLabel: $0) }
            )
        }
        let phones = contact.phoneNumbers.map { entry in
            BindingContactChannel(
                value: entry.value.stringValue,
                label: entry.label.map { CNLabeledValue<NSString>.localizedString(forLabel: $0) }
            )
        }
        let given = contact.givenName.isEmpty ? nil : contact.givenName
        let family = contact.familyName.isEmpty ? nil : contact.familyName
        let organization = contact.organizationName.isEmpty ? nil : contact.organizationName
        let display = [given, family].compactMap { $0 }.joined(separator: " ")
        return BindingContactCandidate(
            identifier: contact.identifier,
            givenName: given,
            familyName: family,
            displayName: display.isEmpty ? organization : display,
            organization: organization,
            jobTitle: contact.jobTitle.isEmpty ? nil : contact.jobTitle,
            emails: emails,
            phones: phones,
            urls: contact.urlAddresses.map { $0.value as String },
            notes: nil,
            groups: []
        )
    }
#endif
}

// MARK: - Coordinators

#if (os(iOS) || os(visionOS)) && canImport(ContactsUI)
private final class BindingContactPickerCoordinator: NSObject, CNContactPickerDelegate {
    private var completion: (([BindingContactCandidate]) -> Void)?

    init(completion: @escaping ([BindingContactCandidate]) -> Void) {
        self.completion = completion
        super.init()
    }

    /// Implementing only the plural callback is what turns on multi-select.
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
        finish(with: contacts.map(BindingContactConversion.candidate(from:)))
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        finish(with: [])
    }

    private func finish(with candidates: [BindingContactCandidate]) {
        guard let completion else { return }
        self.completion = nil
        completion(candidates)
    }
}
#endif

#if os(iOS) || os(visionOS)
private final class BindingDocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
    private var completion: ((URL?) -> Void)?

    init(completion: @escaping (URL?) -> Void) {
        self.completion = completion
        super.init()
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        finish(with: urls.first)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finish(with: nil)
    }

    private func finish(with url: URL?) {
        guard let completion else { return }
        self.completion = nil
        completion(url)
    }
}
#endif
