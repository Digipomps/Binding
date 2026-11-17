import XCTest
@testable import CellBase

final class MeetingSurfaceTests: XCTestCase {
    func testSharedConfigurationAndExportSyntheticParityFixtures() throws {
        let configuration = try MeetingSurfaceConfiguration.make(endpoint: "cell:///synthetic-meeting")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let decoded = try JSONDecoder().decode(CellConfiguration.self, from: encoder.encode(configuration))
        XCTAssertEqual(decoded.cellReferences?.first?.label, "meeting")
        XCTAssertEqual(try encoder.encode(decoded.skeleton), try encoder.encode(configuration.skeleton))
        let a = MeetingPrincipal(id:"Anna",signingKeyFingerprint:"synthetic-a")
        let b = MeetingPrincipal(id:"Bjørn",signingKeyFingerprint:"synthetic-b")
        let c = MeetingPrincipal(id:"Cecilie",signingKeyFingerprint:"synthetic-c")
        let d = MeetingPrincipal(id:"David",signingKeyFingerprint:"synthetic-d")
        let now = Date(timeIntervalSince1970: 1000)
        let s = try MeetingConsentSession(owner:a, plan:MeetingPlan(purpose:"Felles referat",participants:[a,b,c],recorder:a),now:now)
        var snapshots: [(String, MeetingConsentSnapshot)] = [("waiting",try s.snapshot(now:now))]
        let ref = snapshots[0].1.reference
        for p in [a,b,c] { try s.approve(by:p,expected:ref,now:now) }
        snapshots.append(("approved",try s.snapshot(now:now)))
        _ = try s.start(by:a,expected:ref,now:now)
        snapshots.append(("recording",try s.snapshot(now:now)))
        try s.replacePlan(MeetingPlan(purpose:"Felles referat",participants:[a,b,c,d],recorder:a),by:a,expected:ref,now:now)
        snapshots.append(("new-participant",try s.snapshot(now:now)))
        XCTAssertTrue(snapshots.last!.1.approvals.isEmpty)
        let path = ProcessInfo.processInfo.environment["MEETING_FIXTURE_OUTPUT"]
        for (name,snapshot) in snapshots {
            let state = MeetingSurfaceConfiguration.state(snapshot,viewer:a,mediaAvailable:false)
            guard case let .object(values) = state, case let .list(actions)? = values["actions"] else { return XCTFail("State shape") }
            XCTAssertFalse(actions.contains { action in
                guard case let .object(row) = action else { return false }
                return row["keypath"] == .string("meeting.recording.start")
            }, "No start button without a real media adapter")
            if name == "new-participant" {
                guard case let .list(people)? = values["participants"],
                      case let .list(approve)? = values["approveActions"] else { return XCTFail("Missing consent UI") }
                XCTAssertEqual(people.count, 4)
                XCTAssertEqual(approve.count, 1, "The earlier participant must explicitly approve again")
                for person in people {
                    guard case let .object(person) = person else { return XCTFail("Missing participant") }
                    XCTAssertEqual(person["status"], .string("Venter"), "No old approval may survive in the UI")
                }
            }
            if let path {
                for width in [1280,390] {
                    let dir = URL(fileURLWithPath:path).appendingPathComponent("\(name)-\(width)")
                    try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
                    try encoder.encode(configuration.skeleton).write(to:dir.appendingPathComponent("skeleton.json"))
                    try encoder.encode(ValueType.object(["meeting":.object(["state":state])])).write(to:dir.appendingPathComponent("root.json"))
                    try encoder.encode(["width":width,"height":width == 390 ? 1400 : 900]).write(to:dir.appendingPathComponent("viewport.json"))
                    try Data(##"{"padding":0,"contentMaxWidth":1280,"backgroundHex":"#F5F2E9"}"##.utf8).write(to:dir.appendingPathComponent("surface.json"))
                    try encoder.encode([snapshot.recording == nil ? "Mikrofonen er av" : "Tar opp lyd", "Hjelp i chat", "Deltakere", "Anna", "Bjørn", "Cecilie", snapshot.recording != nil ? "Stopp opptak" : snapshot.approvals.isEmpty ? "Godkjenn opptak" : "Trekk tilbake mitt ja"]).write(to:dir.appendingPathComponent("expected-text.json"))
                }
            }
        }
    }
}
