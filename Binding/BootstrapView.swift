import SwiftUI
import CellApple

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
            await AppInitializer.initialize()
            isReady = true
        }
    }
}
