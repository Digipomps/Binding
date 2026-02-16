//
//  RootView.swift
//  Binding
//
//  Created by Kjetil Hustveit on 19/12/2025.
//
import SwiftUI
import CellBase
import CellApple

struct RootView: View {
    @State private var initialized = false

    var body: some View {
        ContentView()
            .overlay(alignment: .top) {
                NotificationConsentBanner()
            }
            .task {
                if !initialized {
                    await AppInitializer.initialize()

                    let resolver = CellResolver.sharedInstance
                    do {
                        try await resolver.addCellResolve(name: "EventEmitter", cellScope: .template, identityDomain: "private", type: EventEmitterCell.self)
                        try await resolver.addCellResolve(name: "FolderWatch", cellScope: .template, identityDomain: "private", type: FolderWatchCell.self)
                    } catch {
                        print("Scaffold added cellResolve failed with error: \(error)")
                    }

                    await MainActor.run {
                        NotificationEnrollmentManager.shared.bootstrapIfNeeded()
                    }
                    initialized = true
                }
            }
    }
}
