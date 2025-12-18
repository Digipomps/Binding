import Foundation
import SwiftUI
import Combine
import CellBase
import CellApple

@MainActor
final class PortholeBindingViewModel: ObservableObject {
    @Published var currentSkeleton: SkeletonElement = .VStack(
        SkeletonVStack(elements: [
            .Text(SkeletonText(text: "Porthole")),
            .Text(SkeletonText(text: "Slipp en CellConfiguration her, eller bruk menykneppene."))
        ])
    )

    private var flowCancellable: AnyCancellable?

    // Keep a weak reference to the resolved porthole if we find one
    private var portholeEmit: Emit?
    private var portholeMeddle: Meddle?

    func connectIfNeeded() async {
        guard portholeEmit == nil || portholeMeddle == nil else { return }
        guard let resolver = CellBase.defaultCellResolver else { return }
        guard let vault = CellBase.defaultIdentityVault as? IdentityVault else { return }
        guard let identity = await vault.identity(for: "private", makeNewIfNotFound: true) else { return }

        do {
            let cell = try await resolver.cellAtEndpoint(endpoint: "cell:///Porthole", requester: identity)
            self.portholeEmit = cell 
            self.portholeMeddle = cell as? Meddle

            if let emit = self.portholeEmit {
                let publisher = try await emit.flow(requester: identity)
                self.flowCancellable = publisher
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] element in
                        guard let self else { return }
                        switch element.content {
                        case .object(let obj):
                            if let skeleton = try? Self.decodeSkeleton(from: obj) {
                                self.currentSkeleton = skeleton
                            }
                        default:
                            break
                        }
                    })
            }
        } catch {
            print("PortholeViewModel: resolving porthole failed: \(error)")
        }
    }

    func load(configuration: CellConfiguration?) async {
        guard let configuration = configuration else { return }
        // Update local UI immediately if the config contains a skeleton
        if let skeleton = configuration.skeleton {
            self.currentSkeleton = skeleton
        }

        // Also try to tell the porthole to load this configuration
        if let meddle = self.portholeMeddle,
           let vault = CellBase.defaultIdentityVault as? IdentityVault,
           let identity = await vault.identity(for: "private", makeNewIfNotFound: true) {
            do {
                _ = try await meddle.set(keypath: "configuration", value: .cellConfiguration(configuration), requester: identity)
            } catch {
                print("PortholeViewModel: setting configuration on porthole failed: \(error)")
            }
        }
    }

    private static func decodeSkeleton(from object: Object) throws -> SkeletonElement {
        let data = try JSONEncoder().encode(object)
        let element = try JSONDecoder().decode(SkeletonElement.self, from: data)
        return element
    }
}

