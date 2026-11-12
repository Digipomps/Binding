// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import XCTest
import CellBase
@testable import Binding

/// Binding declares the host width to the skeleton, as CellApple's PortholeView does,
/// so layout variants (minAvailableWidth/maxAvailableWidth) work in the app too.
final class BindingSkeletonLayoutContextTests: XCTestCase {
    func testUnknownSizeDeclaresNoWidth() {
        XCTAssertNil(BindingSkeletonLayout.context(for: nil).availableWidth)
        XCTAssertNil(BindingSkeletonLayout.context(for: CGSize(width: 0, height: 500)).availableWidth)
    }

    func testMeasuredWidthIsDeclaredAndHeightIsNot() {
        let context = BindingSkeletonLayout.context(for: CGSize(width: 390, height: 4000))
        XCTAssertEqual(context.availableWidth, 390)
        XCTAssertNil(context.availableHeight, "Height inside a ScrollView is content height, not a budget")
    }

    func testWidthSelectsTheMatchingLayoutVariant() throws {
        var modifiers = SkeletonModifiers()
        modifiers.layoutVariants = [
            SkeletonLayoutVariant(maxAvailableWidth: 720, axis: .vertical),
            SkeletonLayoutVariant(axis: .horizontal)
        ]
        XCTAssertEqual(modifiers.layoutVariant(in: BindingSkeletonLayout.context(for: CGSize(width: 390, height: 800)))?.axis, .vertical)
        XCTAssertEqual(modifiers.layoutVariant(in: BindingSkeletonLayout.context(for: CGSize(width: 1440, height: 900)))?.axis, .horizontal)
        XCTAssertEqual(modifiers.layoutVariant(in: BindingSkeletonLayout.context(for: nil))?.axis, .horizontal)
    }
}
