//
//  ContentView.swift
//  Binding
//
//  Created by Kjetil Hustveit on 16/12/2025.
//

import SwiftUI
import Combine
import CellBase
import CellApple

struct ContentView: View {
    @StateObject private var viewModel = PortholeBindingViewModel()
    @State private var menusHidden: Bool = false
    @State private var rotationAccumulator: Angle = .zero

    var body: some View {
        ZStack {
            // Full-screen porthole canvas rendering current skeleton
            PortholeCanvas(skeleton: viewModel.currentSkeleton)
                .ignoresSafeArea()
                .dropDestination(for: CellConfiguration.self) { items, location in
                    // On drop, load the configuration into the porthole
                    Task { await viewModel.load(configuration: items.first) }
                    return !items.isEmpty
                }

            if !menusHidden {
                // Edge menus overlay
                EdgeMenusOverlay(
                    upperLeft: sampleMenuItems(prefix: "UL"),
                    upperMid: sampleMenuItems(prefix: "UM"),
                    upperRight: sampleMenuItems(prefix: "UR"),
                    lowerLeft: sampleMenuItems(prefix: "LL"),
                    lowerMid: sampleMenuItems(prefix: "LM"),
                    lowerRight: sampleMenuItems(prefix: "LR"),
                    onSelect: { config in
                        Task { await viewModel.load(configuration: config) }
                    }
                )
                .allowsHitTesting(true)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .gesture(rotationHideShowGesture)
        .task {
            // Ensure IdentityVault is available for the model
            if CellBase.defaultIdentityVault == nil {
                CellBase.defaultIdentityVault = IdentityVault.shared
                _ = await IdentityVault.shared.initialize()
            }
            await viewModel.connectIfNeeded()
        }
    }

    // MARK: - Rotation gesture to hide/show menus
    private var rotationHideShowGesture: some Gesture {
        RotationGesture()
            .onChanged { angle in
                rotationAccumulator = angle
            }
            .onEnded { angle in
                let threshold: Angle = .degrees(15) // ~0.26 rad ~ 15 degrees
                if angle.radians > threshold.radians {
                    withAnimation(.spring()) { menusHidden = true }
                } else if angle.radians < -threshold.radians {
                    withAnimation(.spring()) { menusHidden = false }
                }
                rotationAccumulator = .zero
            }
    }

    // MARK: - Sample data for menus (replace with real data later)
    private func sampleMenuItems(prefix: String) -> [MenuItem] {
        // Create a few configurations with simple skeletons
        return [
            MenuItem(
                icon: "square.grid.2x2",
                configuration: CellConfiguration(name: "\(prefix) Grid", cellReferences: nil)
            ),
            MenuItem(
                icon: "text.justify",
                configuration: {
                    var conf = CellConfiguration(name: "\(prefix) Text")
                    conf.skeleton = .VStack(
                        SkeletonVStack(elements: [
                            .Text(SkeletonText(text: "\(prefix) – Tittel")),
                            .Text(SkeletonText(text: "Dette er et eksempel på Skeleton UI."))
                        ])
                    )
                    return conf
                }()
            ),
            MenuItem(
                icon: "photo",
                configuration: {
                    var conf = CellConfiguration(name: "\(prefix) Bilde")
                    conf.skeleton = .Image(SkeletonImage(name: "AppIcon"))
                    return conf
                }()
            )
        ]
    }
}

// MARK: - Porthole canvas hosting the Skeleton renderer
private struct PortholeCanvas: View {
    var skeleton: SkeletonElement

    var body: some View {
        ZStack {
            Color(.systemBackground)
            SkeletonView(element: skeleton)
                .padding()
        }
    }
}

// MARK: - Overlay that places six edge menus
// Documentation: See Prompts/EdgeMenusOverlay.md for concepts and guidelines
// Additional project rules: See Prompts/CONTRIBUTING.md and Prompts/Architecture.md
private struct EdgeMenusOverlay: View {
    var upperLeft: [MenuItem]
    var upperMid: [MenuItem]
    var upperRight: [MenuItem]
    var lowerLeft: [MenuItem]
    var lowerMid: [MenuItem]
    var lowerRight: [MenuItem]
    var onSelect: (CellConfiguration) -> Void

    @State private var expanded: Set<EdgePosition> = []

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                EdgeMenu(position: EdgePosition.upperLeft, items: upperLeft, isExpanded: expanded.contains(EdgePosition.upperLeft)) { action(EdgePosition.upperLeft, $0) }
                    .position(x: 32, y: 32)

                EdgeMenu(position: EdgePosition.upperMid, items: upperMid, isExpanded: expanded.contains(EdgePosition.upperMid)) { action(EdgePosition.upperMid, $0) }
                    .position(x: proxy.size.width / 2, y: 32)

                EdgeMenu(position: EdgePosition.upperRight, items: upperRight, isExpanded: expanded.contains(EdgePosition.upperRight)) { action(EdgePosition.upperRight, $0) }
                    .position(x: proxy.size.width - 32, y: 32)

                EdgeMenu(position: EdgePosition.lowerLeft, items: lowerLeft, isExpanded: expanded.contains(EdgePosition.lowerLeft)) { action(EdgePosition.lowerLeft, $0) }
                    .position(x: 32, y: proxy.size.height - 32)

                EdgeMenu(position: EdgePosition.lowerMid, items: lowerMid, isExpanded: expanded.contains(EdgePosition.lowerMid)) { action(EdgePosition.lowerMid, $0) }
                    .position(x: proxy.size.width / 2, y: proxy.size.height - 32)

                EdgeMenu(position: EdgePosition.lowerRight, items: lowerRight, isExpanded: expanded.contains(EdgePosition.lowerRight)) { action(EdgePosition.lowerRight, $0) }
                    .position(x: proxy.size.width - 32, y: proxy.size.height - 32)
            }
            .onPreferenceChange(EdgeMenuToggleKey.self) { pos in
                if let pos { toggle(pos) }
            }
        }
    }

    private func action(_ position: EdgePosition, _ config: CellConfiguration?) {
        if let config { onSelect(config) }
        else { toggle(position) }
    }

    private func toggle(_ position: EdgePosition) {
        withAnimation(.spring()) {
            if expanded.contains(position) { expanded.remove(position) } else { expanded.insert(position) }
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}

