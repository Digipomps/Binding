import Testing
import Foundation
@testable import Binding

@Suite(.serialized) @MainActor
struct PersonEntityReadViewModelTests {
    @Test func selectionNeverConnectsOrReadsAndReadRequiresExplicitCheck() async {
        let model = PersonEntityReadViewModel()
        var connects = 0, reads = 0
        model.select(connection: .init(connect: { connects += 1 }, read: { _ in
            reads += 1; return .init(status: .denied, fragments: [])
        }, close: {}))
        model.read("entityRepresentation.name")
        await Task.yield()
        #expect(connects == 0 && reads == 0)
        #expect(model.phase == .idle)
        model.connect()
        await settle { model.phase == .ready }
        #expect(connects == 1 && reads == 0)
        model.read("entityRepresentation.name")
        await settle { model.result != nil }
        #expect(reads == 1)
        #expect(model.result?.status == .denied)
        #expect(model.message.contains("avvist"))
    }

    @Test func missingReceiptAndInvalidPathsNeverStartNetworkActivity() async {
        let model = PersonEntityReadViewModel()
        model.select(entry: nil)
        model.connect(); model.read("entityRepresentation.name")
        #expect(!model.hasSelection && model.phase == .idle)
        #expect(PersonEntityReadViewModel.keypaths(from: " \n\t") == nil)
        #expect(PersonEntityReadViewModel.keypaths(from: String(repeating: "x", count: 1025)) == nil)
        #expect(PersonEntityReadViewModel.keypaths(from: Array(repeating: "name", count: 17).joined(separator: "\n")) == nil)
        #expect(PersonEntityReadViewModel.keypaths(from: " name \n\n relations.people ") == ["name", "relations.people"])
    }

    @Test func changedSelectionDiscardsAnOldReplyEvenIfTransportIgnoresCancellation() async {
        let model = PersonEntityReadViewModel()
        var held: CheckedContinuation<PersonEntityReadResult, Never>?
        var closed = false
        model.select(connection: .init(connect: {}, read: { _ in
            await withCheckedContinuation { held = $0 }
        }, close: { closed = true }))
        model.connect(); await settle { model.phase == .ready }
        model.read("entityRepresentation.name"); await settle { held != nil }
        model.select(connection: .init(connect: {}, read: { _ in .init(status: .unavailable, fragments: []) }, close: {}))
        model.connect(); await settle { model.phase == .ready }
        held?.resume(returning: .init(status: .complete, fragments: []))
        await settle { closed }
        for _ in 0..<10 { await Task.yield() }
        #expect(model.result == nil)
        #expect(model.phase == .ready)
        model.read("entityRepresentation.name"); await settle { model.result != nil }
        #expect(model.result?.status == .unavailable)
        model.disconnect()
        #expect(model.result == nil && !model.hasSelection)
    }

    @Test func connectionFailureClosesAndNeverClaimsReadiness() async {
        let model = PersonEntityReadViewModel()
        var closed = false
        model.select(connection: .init(connect: { throw CancellationError() }, read: { _ in
            Issue.record("Read must not follow failed connect")
            return .init(status: .complete, fragments: [])
        }, close: { closed = true }))
        model.connect(); await settle { model.phase == .failed }
        model.read("entityRepresentation.name")
        #expect(closed && model.result == nil)
    }

    private func settle(_ condition: () -> Bool) async {
        for _ in 0..<1000 {
            if condition() { return }
            await Task.yield()
        }
        #expect(condition(), "The expected UI state did not arrive")
    }
}
