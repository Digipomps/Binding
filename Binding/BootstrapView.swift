import SwiftUI
import CellBase
import CellApple

actor BindingLocalCellRegistration {
    static let shared = BindingLocalCellRegistration()

    private var isRegistered = false
    private var registrationTask: Task<Void, Never>?

    func ensureRegistered() async {
        if isRegistered {
            return
        }
        if let registrationTask {
            await registrationTask.value
            return
        }

        let task = Task {
            await AppInitializer.initialize()
            let resolver = CellResolver.sharedInstance
            await Self.registerAll(on: resolver)
        }
        registrationTask = task
        await task.value
        isRegistered = true
        registrationTask = nil
    }

    private static func registerAll(on resolver: CellResolver) async {
        await register(
            name: "EventEmitter",
            cellScope: .template,
            identityDomain: "private",
            type: EventEmitterCell.self,
            resolver: resolver
        )
        await register(
            name: "FolderWatch",
            cellScope: .template,
            identityDomain: "private",
            type: FolderWatchCell.self,
            resolver: resolver
        )
        await register(
            name: "AgentEnrollment",
            cellScope: .scaffoldUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: AgentEnrollmentCell.self,
            resolver: resolver
        )
        await register(
            name: "AgentProvisioning",
            cellScope: .scaffoldUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: AgentProvisioningCell.self,
            resolver: resolver
        )
        await register(
            name: "ConfigurationCatalog",
            cellScope: .scaffoldUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: ConfigurationCatalogCell.self,
            resolver: resolver
        )
    }

    private static func register<CellType: Emit & OwnerInstantiable>(
        name: String,
        cellScope: CellUsageScope,
        persistency: Persistancy? = nil,
        identityDomain: String,
        type: CellType.Type,
        resolver: CellResolver
    ) async {
        do {
            if let persistency {
                try await resolver.addCellResolve(
                    name: name,
                    cellScope: cellScope,
                    persistency: persistency,
                    identityDomain: identityDomain,
                    type: type
                )
            } else {
                try await resolver.addCellResolve(
                    name: name,
                    cellScope: cellScope,
                    identityDomain: identityDomain,
                    type: type
                )
            }
        } catch {
            let errorDescription = String(describing: error).lowercased()
            guard !errorDescription.contains("duplicatedendpointname"),
                  !errorDescription.contains("registeratalreadytakenendpoint") else {
                return
            }
            print("Binding local cell registration failed for \(name): \(error)")
        }
    }
}

struct BootstrapView<Content: View>: View {
    @State private var isReady = false
    let content: () -> Content

    var body: some View {
        Group {
            if isReady {
                content()
            } else {
                ProgressView("Starter opp…")
            }
        }
        .task {
            await BindingLocalCellRegistration.shared.ensureRegistered()
            isReady = true
        }
    }
}
