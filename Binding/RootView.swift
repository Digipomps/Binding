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
            .task {
                if !initialized {
                    await AppInitializer.initialize()
                    //            ****** Register scaffold local resolves here ******
                                
                                let resolver = CellResolver.sharedInstance
                                do {
                                    try await resolver.addCellResolve(name: "EventEmitter",         cellScope: .template,       identityDomain: "private", type: EventEmitterCell.self)
//                                    try loadScaffoldCellsDict()
//                                    try await self.setupPorthole()
                                } catch {
                                    print("Scaffold added cellResolve failed with error: \(error)")
                                }
                    
                    initialized = true
                }
            }
    }
    
//    Trying with adding loading scaffold cells and setup porthole copied from CellUtiity
    
}
