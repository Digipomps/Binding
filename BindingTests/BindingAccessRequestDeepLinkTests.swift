import Foundation
import Testing
@testable import Binding

@Suite struct BindingAccessRequestDeepLinkTests {
    private func parse(_ raw: String) -> BindingAccessRequestDeepLink.ParseResult {
        BindingAccessRequestDeepLink.parse(URL(string: raw)!)
    }

    /// Nøyaktig det HavenAgentD lager (`HavenAccessRequestLink.url(contractID:)`).
    @Test func linkFromHavenAgentOpensAccessRequestsWithTheContract() {
        #expect(
            parse("haven://entity-extension/access-requests?contract=elc_tool_ABCdef123456789_x")
                == .accepted(contractID: "elc_tool_ABCdef123456789_x")
        )
        #expect(parse("haven://entity-extension/access-requests") == .accepted(contractID: nil))
        #expect(parse("HAVEN://Entity-Extension/access-requests") == .accepted(contractID: nil))
    }

    @Test func otherRoutesAreLeftForTheirOwnHandlers() {
        #expect(parse("haven://open?schema=haven.surface-launch.v1&surfaceid=x&intent=view") == .notThisRoute)
        #expect(parse("haven://butler/check-in?source=havenagentd") == .notThisRoute)
        #expect(parse("https://entity-extension/access-requests") == .notThisRoute)
    }

    /// Lenken kan bare navigere. Alt som ser ut som mer enn det, avvises og åpnes ikke.
    @Test func anythingBeyondTheContractIsRejected() {
        let rejected: [String] = [
            "haven://entity-extension/approve?contract=elc_tool_x",
            "haven://entity-extension/access-requests/approve",
            "haven://entity-extension/access-requests?contract=elc_tool_x&approve=true",
            "haven://entity-extension/access-requests?approve=elc_tool_x",
            "haven://entity-extension/access-requests?contract=",
            "haven://entity-extension/access-requests?contract=%C3%B8rn",
            "haven://entity-extension/access-requests?contract=a%26approve%3Dtrue",
            "haven://entity-extension/access-requests?contract=elc_tool_x#approve",
            "haven://user@entity-extension/access-requests?contract=elc_tool_x",
            "haven://entity-extension:9/access-requests?contract=elc_tool_x",
            "haven://entity-extension/access-requests?contract=" + String(repeating: "a", count: 129)
        ]
        for raw in rejected {
            guard case .rejected = parse(raw) else {
                Issue.record("Skulle vært avvist: \(raw)")
                continue
            }
        }
        #expect(parse("haven://entity-extension/access-requests?contract=" + String(repeating: "a", count: 128))
            == .accepted(contractID: String(repeating: "a", count: 128)))
    }

    @Test func markingExpiresSoAnOldLinkDoesNotLingerOnTheSurface() {
        let focus = BindingAccessRequestFocus()
        let opened = Date(timeIntervalSince1970: 1_000_000)
        focus.focus(contractID: "elc_tool_x", now: opened)
        #expect(focus.current(now: opened.addingTimeInterval(60)) == "elc_tool_x")
        #expect(focus.current(now: opened.addingTimeInterval(BindingAccessRequestFocus.lifetime + 1)) == nil)
        focus.focus(contractID: nil, now: opened)
        #expect(focus.current(now: opened) == nil)
    }
}
