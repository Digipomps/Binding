//
//  BindingApp.swift
//  Binding
//
//  Created by Kjetil Hustveit on 16/12/2025.
//

import SwiftUI
import CellApple
#if os(macOS)
import AppKit
#endif

@main
struct BindingApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(BindingAppDelegate.self) private var appDelegate
    #endif
    #if os(macOS)
    @NSApplicationDelegateAdaptor(BindingMacAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
        }
#if os(macOS)
        .restorationBehavior(.disabled)
#endif
#if os(macOS)
        .commands {
            BindingConferenceAutomationCommands()
        }
#endif
    }
}

#if os(macOS)
struct BindingConferenceAutomationCommands: Commands {
    var body: some Commands {
        if ContentView.conferenceAutomationGlobalOptInEnabled(
            environment: ProcessInfo.processInfo.environment,
            launchArguments: ProcessInfo.processInfo.arguments,
            persistedOptIn: UserDefaults.standard.bool(forKey: ContentView.conferenceAutomationDefaultsKey)
        ) {
            CommandMenu("Conference Automation") {
                Button(ContentView.ConferenceAutomationHook.openLauncher.title) {
                    post(.openLauncher)
                }
                Button(ContentView.ConferenceAutomationHook.openParticipantPortal.title) {
                    post(.openParticipantPortal)
                }
                Button(ContentView.ConferenceAutomationHook.openPublicSurface.title) {
                    post(.openPublicSurface)
                }
                Button(ContentView.ConferenceAutomationHook.openControlTower.title) {
                    post(.openControlTower)
                }
                Button(ContentView.ConferenceAutomationHook.openAIAssistant.title) {
                    post(.openAIAssistant)
                }
                Button(ContentView.ConferenceAutomationHook.logAIAssistantState.title) {
                    post(.logAIAssistantState)
                }
                Button(ContentView.ConferenceAutomationHook.openIdentityLink.title) {
                    post(.openIdentityLink)
                }

                Divider()

                Button(ContentView.ConferenceAutomationHook.focusAneSolberg.title) {
                    post(.focusAneSolberg)
                }
                Button(ContentView.ConferenceAutomationHook.startChatWithFocusedParticipant.title) {
                    post(.startChatWithFocusedParticipant)
                }
                Button(ContentView.ConferenceAutomationHook.openFocusedChatWorkbench.title) {
                    post(.openFocusedChatWorkbench)
                }

                Divider()

                Button(ContentView.ConferenceAutomationHook.windowCompact.title) {
                    post(.windowCompact)
                }
                Button(ContentView.ConferenceAutomationHook.windowTall.title) {
                    post(.windowTall)
                }
                Button(ContentView.ConferenceAutomationHook.windowWide.title) {
                    post(.windowWide)
                }
                Button(ContentView.ConferenceAutomationHook.centerWindow.title) {
                    post(.centerWindow)
                }
            }
        }
    }

    private func post(_ hook: ContentView.ConferenceAutomationHook) {
        BindingConferenceAutomationBridge.post(
            hook: hook,
            targetWindowNumber: NSApp.keyWindow?.windowNumber
                ?? NSApp.mainWindow?.windowNumber
                ?? NSApp.orderedWindows.first(where: \.isVisible)?.windowNumber
        )
    }
}
#endif
