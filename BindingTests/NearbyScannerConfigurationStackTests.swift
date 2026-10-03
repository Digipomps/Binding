import XCTest
import CellBase
@testable import Binding

final class NearbyScannerConfigurationStackTests: XCTestCase {
    func testScannerConfigurationsFitWithinConstrainedUIStack() async {
        let completed = expectation(description: "Scanner configurations fit in 512 KiB")
        let thread = Thread {
            autoreleasepool {
                // macOS's main stack hid the iPad crash. Keep this smaller than
                // the device UI stack and exercise both the catalog and sidebar
                // paths repeatedly without starting radio or accessing a vault.
                for _ in 0..<20 {
                    let catalog = ConfigurationCatalogCell.entityScannerWorkbenchConfiguration()
                    XCTAssertEqual(catalog.name, "Entity Scanner")
                    XCTAssertNotNil(catalog.skeleton)
                    let sidebar = ConfigurationCatalogCell.entityScannerForPersonalCopilotConfiguration()
                    XCTAssertEqual(sidebar.name, "Entity Scanner")
                    XCTAssertNotNil(sidebar.skeleton)
                }
                completed.fulfill()
            }
        }
        thread.stackSize = 512 * 1024
        thread.start()
        await fulfillment(of: [completed], timeout: 10)
    }
}
