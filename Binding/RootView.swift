//
//  RootView.swift
//  Binding
//
//  Created by Kjetil Hustveit on 19/12/2025.
//
import SwiftUI
import CellBase
import CellApple
#if canImport(DiMyCellProtocolCells)
import DiMyCellProtocolCells
#endif

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
#if canImport(DiMyCellProtocolCells)
                    do {
                        try await DiMyCellRuntimeRegistration.registerBindingCells(
                            resolver: resolver,
                            identityDomain: "private"
                        )
                    } catch {
                        print("DiMy micropayment cell registration failed with error: \(error)")
                    }
#endif

                    await MainActor.run {
                        NotificationEnrollmentManager.shared.bootstrapIfNeeded()
                    }
                    initialized = true
                }
            }
    }
}
