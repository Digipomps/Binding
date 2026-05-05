import Foundation
import UniformTypeIdentifiers
import SwiftUI
import CellBase
import CellApple

extension UTType {
    static let cellConfiguration = UTType(importedAs: "app.binding.cellconfiguration")
}

extension CellConfiguration: @retroactive @unchecked Sendable {}
extension CellConfiguration: @retroactive Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .cellConfiguration)
    }
}

