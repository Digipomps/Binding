//
//  RootView.swift
//  Binding
//
//  Created by Kjetil Hustveit on 19/12/2025.
//
import SwiftUI
import CellApple

struct RootView: View {
    @State private var initialized = false

    var body: some View {
        ContentView()
            .task {
                if !initialized {
                    await AppInitializer.initialize()
                    initialized = true
                }
            }
    }
}
