import XCTest
@testable import Mttone

final class DatabaseManagerTests: XCTestCase {

    // 注意：完整的 DatabaseManager 测试需要在 Xcode 中运行
    // 这里提供测试骨架，后续补充具体测试用例

    func testMeetingCreation() throws {
        let db = DatabaseManager()
        let meeting = Meeting.create(title: "测试会议", location: "会议室 A")

        try db.createMeeting(meeting)

        let meetings = db.fetchAllMeetings()
        XCTAssertFalse(meetings.isEmpty)
        XCTAssertEqual(meetings.first?.title, "测试会议")
        XCTAssertEqual(meetings.first?.location, "会议室 A")
        XCTAssertEqual(meetings.first?.status, .recording)
    }

    func testMeetingStatusUpdate() throws {
        let db = DatabaseManager()
        let meeting = Meeting.create(title: "状态测试")
        try db.createMeeting(meeting)

        try db.updateMeetingStatus(id: meeting.id, status: .completed, duration: 120)

        let meetings = db.fetchAllMeetings()
        let updated = meetings.first { $0.id == meeting.id }
        XCTAssertEqual(updated?.status, .completed)
        XCTAssertEqual(updated?.duration, 120)
    }
}
