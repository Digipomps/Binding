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
    var body: some Scene {
        WindowGroup {
            BootstrapView {
                RootView()
            }
        }
    }
}

