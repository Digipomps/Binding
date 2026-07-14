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
    @State private var initializationFailure: String?
    @State private var initializationAttemptID = UUID()
    @State private var incomingURLSceneID = UUID()
    @State private var incomingURLDeliveryFailed = false

    var body: some View {
        rootContent
        .environment(\.bindingRuntimeSurfaceTargetSceneID, incomingURLSceneID)
        .task(id: initializationAttemptID) {
            // XCTest launches the HAVEN app as the host process for unit tests.
            // Starting the production runtime here races tests that deliberately
            // replace the global vault/resolver and can re-install cells owned by
            // the previous identity after a reset. UI-test app launches do not
            // carry XCTestConfigurationFilePath and still exercise normal startup.
            guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
                return
            }
            if !initialized {
                await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
                let locallyRegistered = await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
                guard locallyRegistered else {
                    await MainActor.run {
                        initializationFailure = "De lokale HAVEN-cellene kunne ikke valideres. Ingen arbeidsflate er åpnet med en delvis initialisert runtime."
                    }
                    return
                }

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
                    PendingActionInboxViewModel.shared.reloadPersistedActions()
                    initializationFailure = nil
                    initialized = true
                }
            }
        }
#if os(iOS)
        .onOpenURL { url in
            BindingIncomingURLBridge.submit(
                url: url,
                targetSceneID: incomingURLSceneID
            )
        }
#endif
        .onReceive(NotificationCenter.default.publisher(
            for: BindingIncomingURLBridge.deliveryFailureNotificationName
        )) { _ in
            incomingURLDeliveryFailed = true
        }
        .alert("Kunne ikke åpne lenken", isPresented: $incomingURLDeliveryFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("HAVEN var opptatt med andre lenker. Prøv igjen når den pågående åpningen er ferdig.")
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if initialized {
            ContentView(incomingURLSceneID: incomingURLSceneID)
                .overlay(alignment: .top) {
                    NotificationConsentBanner()
                }
                .overlay(alignment: .bottom) {
                    PendingAgentActionOverlay()
                }
        } else if let initializationFailure {
            ZStack {
                launchBackgroundColor
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundStyle(.orange)
                    Text("HAVEN-runtime kunne ikke startes")
                        .font(.headline)
                    Text(initializationFailure)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Prøv igjen") {
                        self.initializationFailure = nil
                        initializationAttemptID = UUID()
                    }
                }
                .frame(maxWidth: 460)
                .padding(24)
            }
        } else {
            ZStack {
                launchBackgroundColor
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Starter HAVEN-runtime…")
                        .font(.headline)
                    Text("Laster lokale celler og demooppsett før arbeidsflaten vises.")
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
