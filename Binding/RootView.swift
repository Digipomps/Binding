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
        rootContent
        .task {
            if !initialized {
                await BindingLocalCellRegistration.shared.ensureLaunchCriticalCellsRegistered()

                await MainActor.run {
                    NotificationEnrollmentManager.shared.bootstrapIfNeeded()
                    PendingActionInboxViewModel.shared.reloadPersistedActions()
                    initialized = true
                }

                Task {
                    await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
#if canImport(DiMyCellProtocolCells)
                    do {
                        try await DiMyCellRuntimeRegistration.registerBindingCells(
                            resolver: CellResolver.sharedInstance,
                            identityDomain: "private"
                        )
                    } catch {
                        print("DiMy micropayment cell registration failed with error: \(error)")
                    }
#endif
                }
            }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if initialized {
            ContentView()
                .overlay(alignment: .top) {
                    NotificationConsentBanner()
                }
                .overlay(alignment: .bottom) {
                    PendingAgentActionOverlay()
                }
        } else {
            ZStack {
                launchBackgroundColor
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Starter HAVEN-runtime…")
                        .font(.headline)
                    Text("Klargjør privat chat og arbeidsflate.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
        }
    }

    private var launchBackgroundColor: Color {
#if os(iOS)
        Color(uiColor: .systemBackground)
#else
        Color(nsColor: .windowBackgroundColor)
#endif
    }
}
