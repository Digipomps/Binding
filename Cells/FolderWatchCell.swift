//
//  FolderWatchCell.swift
//  Binding
//
//  Created by Codex on 15/02/2026.
//

import Foundation
import CellBase
import Dispatch
import Darwin

final class FolderWatchCell: GeneralCell {
    private enum WatchEvent: String, CaseIterable, Codable {
        case write
        case delete
        case extend
        case attrib
        case link
        case rename
        case revoke

        var dispatchFlag: DispatchSource.FileSystemEvent {
            switch self {
            case .write: return .write
            case .delete: return .delete
            case .extend: return .extend
            case .attrib: return .attrib
            case .link: return .link
            case .rename: return .rename
            case .revoke: return .revoke
            }
        }
    }

    private struct WatchConfiguration {
        var path: String?
        var topic: String?
        var events: Set<WatchEvent>?
    }

    private enum WatchError: Error {
        case missingPath
        case invalidPayload
        case invalidPath(String)
        case noEvents
        case openFailed(String, Int32)

        var message: String {
            switch self {
            case .missingPath:
                return "missing watch path"
            case .invalidPayload:
                return "invalid payload"
            case .invalidPath(let path):
                return "path does not exist: \(path)"
            case .noEvents:
                return "no events selected"
            case .openFailed(let path, let code):
                return "failed to open path '\(path)' (errno \(code))"
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case configuredPath
        case configuredTopic
        case configuredEvents
    }

    private nonisolated static let defaultTopic = "filesystem.watch"
    private nonisolated static let defaultEvents: Set<WatchEvent> = [.write, .delete, .rename, .attrib]

    private let stateQueue = DispatchQueue(label: "Binding.FolderWatchCell.State")
    private let watchQueue = DispatchQueue(label: "Binding.FolderWatchCell.Watch")

    // Codable entrypoints are nonisolated; queue-backed configuration keeps them synchronized.
    private nonisolated(unsafe) var configuredPath: String?
    private nonisolated(unsafe) var configuredTopic: String = FolderWatchCell.defaultTopic
    private nonisolated(unsafe) var configuredEvents: Set<WatchEvent> = FolderWatchCell.defaultEvents

    private var source: DispatchSourceFileSystemObject?
    private var watchedFileDescriptor: Int32 = -1
    private var running: Bool = false

    private var lastEventAt: Double?
    private var lastEventPayload: Object?
    private var pathSnapshot: [String: TimeInterval] = [:]

    required init(owner: Identity) async {
        await super.init(owner: owner)
        try? await ensureRuntimeReady()
    }

    nonisolated required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        configuredPath = try container.decodeIfPresent(String.self, forKey: .configuredPath)
        configuredTopic = try container.decodeIfPresent(String.self, forKey: .configuredTopic) ?? Self.defaultTopic
        configuredEvents = try container.decodeIfPresent(Set<WatchEvent>.self, forKey: .configuredEvents) ?? Self.defaultEvents

        try super.init(from: decoder)
    }

    override func installCellRuntimeBindingsForAccess() async throws {
        let owner = storedOwnerIdentity
        await setupPermissions(owner: owner)
        await setupKeys(owner: owner)
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        let snapshot = stateQueue.sync {
            (
                path: configuredPath,
                topic: configuredTopic,
                events: configuredEvents
            )
        }
        try container.encodeIfPresent(snapshot.path, forKey: .configuredPath)
        try container.encode(snapshot.topic, forKey: .configuredTopic)
        try container.encode(snapshot.events, forKey: .configuredEvents)
    }

    private func setupPermissions(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("r---", for: "flow")
        agreementTemplate.addGrant("rw--", for: "configure")
        agreementTemplate.addGrant("rw--", for: "start")
        agreementTemplate.addGrant("rw--", for: "stop")
    }

    private func setupKeys(owner: Identity) async {
        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self = self else { return .string("failure") }
            guard await self.validateAccess("r---", at: "state", for: requester) else { return .string("denied") }
            return self.stateValue()
        })

        await addInterceptForSet(requester: owner, key: "configure", setValueIntercept: { [weak self] _, value, requester in
            guard let self = self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "configure", for: requester) else { return .string("denied") }
            do {
                let configuration = try self.parseConfiguration(from: value, allowEmpty: false)
                try self.apply(configuration: configuration)
                return self.stateValue()
            } catch let error as WatchError {
                return .string("error: \(error.message)")
            } catch {
                return .string("error: \(error.localizedDescription)")
            }
        })

        await addInterceptForSet(requester: owner, key: "start", setValueIntercept: { [weak self] _, value, requester in
            guard let self = self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "start", for: requester) else { return .string("denied") }
            return await self.start(payload: value)
        })

        await addInterceptForSet(requester: owner, key: "stop", setValueIntercept: { [weak self] _, _, requester in
            guard let self = self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "stop", for: requester) else { return .string("denied") }
            self.stopWatching()
            return self.stateValue()
        })

        // Keep compatibility with existing cells that trigger actions via GET.
        await addInterceptForGet(requester: owner, key: "start", getValueIntercept: { [weak self] _, requester in
            guard let self = self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "start", for: requester) else { return .string("denied") }
            return await self.start(payload: .null)
        })

        await addInterceptForGet(requester: owner, key: "stop", getValueIntercept: { [weak self] _, requester in
            guard let self = self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "stop", for: requester) else { return .string("denied") }
            self.stopWatching()
            return self.stateValue()
        })
    }

    private func start(payload: ValueType) async -> ValueType {
        do {
            let configuration = try parseConfiguration(from: payload, allowEmpty: true)
            try apply(configuration: configuration)
            try startWatching()
            return stateValue()
        } catch let error as WatchError {
            return .string("error: \(error.message)")
        } catch {
            return .string("error: \(error.localizedDescription)")
        }
    }

    private func parseConfiguration(from payload: ValueType, allowEmpty: Bool) throws -> WatchConfiguration {
        switch payload {
        case .null:
            if allowEmpty { return WatchConfiguration(path: nil, topic: nil, events: nil) }
            throw WatchError.invalidPayload
        case .string(let path):
            let cleanedPath = normalizePath(path)
            guard !cleanedPath.isEmpty else { throw WatchError.invalidPayload }
            return WatchConfiguration(path: cleanedPath, topic: nil, events: nil)
        case .object(let object):
            let pathValue = object["path"] ?? object["watchPath"]
            let topicValue = object["topic"]
            let eventsValue = object["events"] ?? object["watchEvents"]

            let path: String? = {
                guard let pathValue else { return nil }
                guard case let .string(path) = pathValue else { return nil }
                let cleaned = normalizePath(path)
                return cleaned.isEmpty ? nil : cleaned
            }()
            if pathValue != nil, path == nil {
                throw WatchError.invalidPayload
            }

            let topic: String? = {
                guard let topicValue else { return nil }
                guard case let .string(topic) = topicValue else { return nil }
                let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }()
            if topicValue != nil, topic == nil {
                throw WatchError.invalidPayload
            }

            let events: Set<WatchEvent>? = try {
                guard let eventsValue else { return nil }
                let parsed = try parseEvents(from: eventsValue)
                guard !parsed.isEmpty else { throw WatchError.noEvents }
                return parsed
            }()

            if !allowEmpty, path == nil, topic == nil, events == nil {
                throw WatchError.invalidPayload
            }

            return WatchConfiguration(path: path, topic: topic, events: events)
        default:
            throw WatchError.invalidPayload
        }
    }

    private func parseEvents(from value: ValueType) throws -> Set<WatchEvent> {
        switch value {
        case .string(let eventList):
            let names = eventList
                .split(whereSeparator: { $0 == "," || $0 == ";" || $0.isWhitespace })
                .map { $0.lowercased() }
            return try parseEventNames(names)
        case .list(let entries):
            let names = try entries.map { entry -> String in
                guard case let .string(raw) = entry else { throw WatchError.invalidPayload }
                return raw.lowercased()
            }
            return try parseEventNames(names)
        default:
            throw WatchError.invalidPayload
        }
    }

    private func parseEventNames<S: Sequence>(_ names: S) throws -> Set<WatchEvent> where S.Element == String {
        var parsed: Set<WatchEvent> = []
        for name in names {
            guard let event = WatchEvent(rawValue: name) else { throw WatchError.invalidPayload }
            parsed.insert(event)
        }
        return parsed
    }

    private func apply(configuration: WatchConfiguration) throws {
        var shouldRestart = false
        stateQueue.sync {
            if let newPath = configuration.path, configuredPath != newPath {
                configuredPath = newPath
                shouldRestart = true
            }
            if let newTopic = configuration.topic, configuredTopic != newTopic {
                configuredTopic = newTopic
            }
            if let newEvents = configuration.events, configuredEvents != newEvents {
                configuredEvents = newEvents
                shouldRestart = true
            }
        }

        if shouldRestart, isRunning() {
            try restartWatching()
        }
    }

    private func isRunning() -> Bool {
        stateQueue.sync { running }
    }

    private func restartWatching() throws {
        stopWatching()
        try startWatching()
    }

    private func startWatching() throws {
        let snapshot = stateQueue.sync { (path: configuredPath, events: configuredEvents) }
        guard let path = snapshot.path, !path.isEmpty else { throw WatchError.missingPath }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw WatchError.invalidPath(path)
        }

        stopWatching()

        let descriptor = open(path, O_RDONLY)
        guard descriptor >= 0 else {
            throw WatchError.openFailed(path, errno)
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: dispatchMask(from: snapshot.events),
            queue: watchQueue
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let mask = self.stateQueue.sync { self.source?.data ?? [] }
            Task {
                await self.handleFilesystemEvent(mask: mask)
            }
        }

        source.setCancelHandler {
            _DarwinFoundation3.close(descriptor)
        }

        stateQueue.sync {
            self.source = source
            self.watchedFileDescriptor = descriptor
            self.running = true
            self.pathSnapshot = self.snapshotForPath(path, isDirectory: isDirectory.boolValue)
        }

        source.resume()
    }

    private func stopWatching() {
        let sourceToCancel = stateQueue.sync { () -> DispatchSourceFileSystemObject? in
            let current = source
            source = nil
            watchedFileDescriptor = -1
            running = false
            return current
        }
        sourceToCancel?.cancel()
    }

    private func dispatchMask(from events: Set<WatchEvent>) -> DispatchSource.FileSystemEvent {
        var mask: DispatchSource.FileSystemEvent = []
        for event in events {
            mask.formUnion(event.dispatchFlag)
        }
        return mask
    }

    private func eventNames(from mask: DispatchSource.FileSystemEvent) -> [String] {
        WatchEvent.allCases
            .filter { mask.contains($0.dispatchFlag) }
            .map(\.rawValue)
    }

    private func snapshotForPath(_ path: String, isDirectory: Bool) -> [String: TimeInterval] {
        if isDirectory {
            return snapshotForDirectory(path)
        }
        let modifiedAt = modificationTimestamp(for: path) ?? 0
        return [path: modifiedAt]
    }

    private func snapshotForDirectory(_ path: String) -> [String: TimeInterval] {
        guard let children = try? FileManager.default.contentsOfDirectory(atPath: path) else { return [:] }

        var snapshot: [String: TimeInterval] = [:]
        for child in children {
            let fullPath = (path as NSString).appendingPathComponent(child)
            snapshot[child] = modificationTimestamp(for: fullPath) ?? 0
        }
        return snapshot
    }

    private func modificationTimestamp(for path: String) -> TimeInterval? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let date = attributes[.modificationDate] as? Date else {
            return nil
        }
        return date.timeIntervalSince1970
    }

    private func handleFilesystemEvent(mask: DispatchSource.FileSystemEvent) async {
        guard !mask.isEmpty else { return }

        let snapshot = stateQueue.sync {
            (
                running: running,
                path: configuredPath,
                topic: configuredTopic
            )
        }
        guard snapshot.running, let path = snapshot.path else { return }

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        let currentSnapshot = exists ? snapshotForPath(path, isDirectory: isDirectory.boolValue) : [:]

        let diff = stateQueue.sync { () -> (added: [String], removed: [String], modified: [String]) in
            let previous = pathSnapshot
            pathSnapshot = currentSnapshot

            let added = currentSnapshot.keys.filter { previous[$0] == nil }.sorted()
            let removed = previous.keys.filter { currentSnapshot[$0] == nil }.sorted()
            let modified = currentSnapshot.keys.filter { key in
                guard let currentValue = currentSnapshot[key], let previousValue = previous[key] else { return false }
                return currentValue != previousValue
            }.sorted()
            return (added, removed, modified)
        }

        let now = Date().timeIntervalSince1970
        var payload: Object = [
            "path": .string(path),
            "exists": .bool(exists),
            "isDirectory": .bool(isDirectory.boolValue),
            "detectedAt": .float(now),
            "events": .list(eventNames(from: mask).map { .string($0) })
        ]
        payload["added"] = .list(diff.added.map { .string($0) })
        payload["removed"] = .list(diff.removed.map { .string($0) })
        payload["modified"] = .list(diff.modified.map { .string($0) })

        stateQueue.sync {
            lastEventAt = now
            lastEventPayload = payload
        }

        var flowElement = FlowElement(
            title: "filesystem.watch.event",
            content: .object(payload),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flowElement.topic = snapshot.topic
        flowElement.origin = uuid

        if let vault = CellBase.defaultIdentityVault,
           let requester = await vault.identity(for: "private", makeNewIfNotFound: true) {
            pushFlowElement(flowElement, requester: requester)
        }
    }

    private func stateValue() -> ValueType {
        let snapshot = stateQueue.sync {
            (
                path: configuredPath,
                topic: configuredTopic,
                events: configuredEvents,
                running: running,
                fd: watchedFileDescriptor,
                lastEventAt: lastEventAt,
                lastEventPayload: lastEventPayload
            )
        }

        var object: Object = [
            "running": .bool(snapshot.running),
            "topic": .string(snapshot.topic),
            "events": .list(snapshot.events.map(\.rawValue).sorted().map { .string($0) }),
            "descriptor": .integer(Int(snapshot.fd))
        ]
        if let path = snapshot.path {
            object["path"] = .string(path)
        } else {
            object["path"] = .null
        }
        if let lastEventAt = snapshot.lastEventAt {
            object["lastEventAt"] = .float(lastEventAt)
        }
        if let lastEventPayload = snapshot.lastEventPayload {
            object["lastEvent"] = .object(lastEventPayload)
        }
        return .object(object)
    }

    private func normalizePath(_ rawPath: String) -> String {
        let expanded = (rawPath as NSString).expandingTildeInPath
        return (expanded as NSString).standardizingPath
    }
}
