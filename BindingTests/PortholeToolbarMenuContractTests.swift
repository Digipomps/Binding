// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Testing
@testable import Binding

@MainActor
@Suite
struct PortholeToolbarMenuContractTests {
    @Test func sixStableMenuSlotsKeepSchemaIdentityAndHumanLabels() {
        let positions = EdgePosition.allCases
        let keypaths = positions.map(\.menuSlotKeypath)

        #expect(keypaths == [
            "upperLeftMenu",
            "upperMidMenu",
            "upperRightMenu",
            "lowerLeftMenu",
            "lowerMidMenu",
            "lowerRightMenu",
        ])
        #expect(Set(keypaths).count == 6)
        #expect(positions.map(\.localizedTitle) == [
            "Hovedmeny",
            "Flater",
            "Flere flater",
            "Kontroll",
            "Favoritter",
            "Åpne og last inn",
        ])
    }

    @Test func edgeMenuPresentationStaysWithinTenTargets() {
        let atLimit = EdgeMenu.presentationPlan(for: 10)
        #expect(atLimit.visibleCount == 10)
        #expect(atLimit.showsAll == false)

        let overflow = EdgeMenu.presentationPlan(for: 11)
        #expect(overflow.visibleCount == 9)
        #expect(overflow.showsAll)
        #expect(overflow.visibleCount + 1 == EdgeMenu.presentationLimit)
    }
}
