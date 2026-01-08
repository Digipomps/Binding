import Foundation
import CellBase

public final class CounterCell: GeneralCell, Codable {
    private var value: Int = 0

    // MARK: - Init (required)
    public required init(owner: Identity) async {
        await super.init(owner: owner)
        self.name = "Counter"
        await setupPermissions(owner: owner)
        await setupKeys(owner: owner)
    }

    // MARK: - Permissions
    private func setupPermissions(owner: Identity) async {
        // Allow read of feed (events) and counter state
        self.agreementTemplate.addGrant("r---", for: "flow")
        self.agreementTemplate.addGrant("r---", for: "counter")
        self.agreementTemplate.addGrant("-w--", for: "counter")
    }

    // MARK: - Keys (get/set endpoints)
    private func setupKeys(owner: Identity) async {
        // GET counter.value -> returns current value
        await addInterceptForGet(requester: owner, key: "counter", getValueIntercept: { [weak self] keypath, requester in
            guard let self = self else { return .string("error") }
            // Optional: enforce read access
            if await self.validateAccess("r---", at: "counter", for: requester) {
                return .integer(self.value)
            }
            throw GeneralCell.KeyValueErrors.denied
        })

        // SET counter.increment -> increments by 1 (or by payload if provided)
        await addInterceptForSet(requester: owner, key: "counter.increment", setValueIntercept: { [weak self] keypath, value, requester in
            guard let self = self else { return .string("failure") }
            if await self.validateAccess("-w--", at: "counter", for: requester) {
                let delta: Int = {
                    if case let .integer(i) = value { return i }
                    if case let .number(n) = value { return Int(n) }
                    return 1
                }()
                self.value += delta
                // Optionally emit a feed event
                var msg = FlowElement(title: "Counter updated", content: .integer(self.value), properties: .init(type: .event, contentType: .string))
                msg.topic = "counter"
                msg.origin = self.uuid
                self.pushFlowElement(msg, requester: requester)
                return .integer(self.value)
            }
            return .string("denied")
        })

        // SET counter.set -> sets the counter to an explicit value
        await addInterceptForSet(requester: owner, key: "counter.set", setValueIntercept: { [weak self] keypath, value, requester in
            guard let self = self else { return .string("failure") }
            if await self.validateAccess("-w--", at: "counter", for: requester) {
                let newValue: Int = {
                    if case let .integer(i) = value { return i }
                    if case let .number(n) = value { return Int(n) }
                    return self.value
                }()
                self.value = newValue
                var msg = FlowElement(title: "Counter set", content: .integer(self.value), properties: .init(type: .event, contentType: .string))
                msg.topic = "counter"
                msg.origin = self.uuid
                self.pushFlowElement(msg, requester: requester)
                return .integer(self.value)
            }
            return .string("denied")
        })

        // Optional: Flow intercept (transform/observe incoming FlowElements)
        await addIntercept(requester: owner, intercept: { [weak self] flowElement, requester in
            guard let self = self else { return nil }
            // Example: log or transform elements with topic == "counter"
            if flowElement.topic == "counter" { return flowElement }
            return nil // return nil to forward unchanged; return a FlowElement to replace
        })
    }

    // MARK: - Codable (for persisted cells)
    enum CodingKeys: String, CodingKey { case value }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.value = try container.decodeIfPresent(Int.self, forKey: .value) ?? 0
        try super.init(from: decoder)

        // Recreate async setup after decode
        Task {
            if let vault = CellBase.defaultIdentityVault,
               let requester = await vault.identity(for: "private", makeNewIfNotFound: true) {
                await self.setupPermissions(owner: requester)
                await self.setupKeys(owner: requester)
            }
        }
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.value, forKey: .value)
        try super.encode(to: encoder)
    }
}

## 6) Use your cell via get/set

This section shows how to use your cell with get/set operations.

## Practical pattern: 'state' snapshot + incremental updates via Flow

A common pattern is to expose a full `state` snapshot via `GET state`, and emit incremental updates as FlowElements when internal data changes. Consumers can fetch the full state once and then subscribe to updates. You can use different topics and element types (e.g., `.content` for full snapshots, `.event` for incremental changes).

Example cell that maintains an in‑memory list and publishes updates:

```swift:IncrementalListCell.swift
import Foundation
import CellBase

public final class IncrementalListCell: GeneralCell, Codable {
    private var items: [String] = []

    public required init(owner: Identity) async {
        await super.init(owner: owner)
        self.name = "IncrementalList"
        await setupPermissions(owner: owner)
        await setupKeys(owner: owner)
    }

    private func setupPermissions(owner: Identity) async {
        self.agreementTemplate.addGrant("r---", for: "flow")
        self.agreementTemplate.addGrant("r---", for: "state")
        self.agreementTemplate.addGrant("-w--", for: "items")
    }

    private func setupKeys(owner: Identity) async {
        // GET state -> return full snapshot
        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] keypath, requester in
            guard let self = self else { return .string("error") }
            if await self.validateAccess("r---", at: "state", for: requester) {
                return self.snapshotValue()
            }
            throw GeneralCell.KeyValueErrors.denied
        })

        // SET items.add -> append item and emit incremental + optional full snapshot
        await addInterceptForSet(requester: owner, key: "items.add", setValueIntercept: { [weak self] keypath, value, requester in
            guard let self = self else { return .string("failure") }
            if await self.validateAccess("-w--", at: "items", for: requester) {
                let newItem: String = {
                    if case let .string(s) = value { return s }
                    if case let .object(o) = value, let .string(s) = o["text"] { return s }
                    return ""
                }()
                self.items.append(newItem)

                // 1) Incremental event
                var event = FlowElement(
                    title: "Item added",
                    content: .object(["text": .string(newItem), "index": .integer(self.items.count - 1)]),
                    properties: .init(type: .event, contentType: .dslv17)
                )
                event.topic = "items"
                event.origin = self.uuid
                self.pushFlowElement(event, requester: requester)

                // 2) Full state snapshot (content)
                var snapshotEl = FlowElement(
                    title: "State",
                    content: self.snapshotValue(),
                    properties: .init(type: .content, contentType: .dslv17)
                )
                snapshotEl.topic = "state"
                snapshotEl.origin = self.uuid
                self.pushFlowElement(snapshotEl, requester: requester)

                return .string("ok")
            }
            return .string("denied")
        })

        // SET items.remove -> remove by index and emit updates
        await addInterceptForSet(requester: owner, key: "items.remove", setValueIntercept: { [weak self] keypath, value, requester in
            guard let self = self else { return .string("failure") }
            if await self.validateAccess("-w--", at: "items", for: requester) {
                let idx: Int = {
                    if case let .integer(i) = value { return i }
                    if case let .number(n) = value { return Int(n) }
                    return -1
                }()
                guard idx >= 0 && idx < self.items.count else { return .string("index out of range") }
                let removed = self.items.remove(at: idx)

                var event = FlowElement(
                    title: "Item removed",
                    content: .object(["text": .string(removed), "index": .integer(idx)]),
                    properties: .init(type: .event, contentType: .dslv17)
                )
                event.topic = "items"
                event.origin = self.uuid
                self.pushFlowElement(event, requester: requester)

                var snapshotEl = FlowElement(
                    title: "State",
                    content: self.snapshotValue(),
                    properties: .init(type: .content, contentType: .dslv17)
                )
                snapshotEl.topic = "state"
                snapshotEl.origin = self.uuid
                self.pushFlowElement(snapshotEl, requester: requester)

                return .string("ok")
            }
            return .string("denied")
        })
    }

    private func snapshotValue() -> ValueType {
        var arr = ValueTypeList()
        for s in items { arr.append(.string(s)) }
        return .object([
            "items": .list(arr),
            "count": .integer(items.count)
        ])
    }

    // MARK: - Codable (for persistence)
    enum CodingKeys: String, CodingKey { case items }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try container.decodeIfPresent([String].self, forKey: .items) ?? []
        try super.init(from: decoder)
        Task {
            if let vault = CellBase.defaultIdentityVault,
               let requester = await vault.identity(for: "private", makeNewIfNotFound: true) {
                await self.setupPermissions(owner: requester)
                await self.setupKeys(owner: requester)
            }
        }
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.items, forKey: .items)
        try super.encode(to: encoder)
    }
}
