import Foundation
import UniformTypeIdentifiers
import SwiftUI

extension UTType {
    static let cellConfiguration = UTType(exportedAs: "app.binding.cellconfiguration")
}

extension CellConfiguration: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .cellConfiguration)
    }
}
