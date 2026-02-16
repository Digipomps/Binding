//
//  BindingApp.swift
//  Binding
//
//  Created by Kjetil Hustveit on 16/12/2025.
//

import SwiftUI
import CellApple

@main
struct BindingApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(BindingAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            BootstrapView {
                RootView()
            }
        }
    }
}
