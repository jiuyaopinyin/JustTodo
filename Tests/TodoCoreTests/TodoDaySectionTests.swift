import XCTest
@testable import TodoCore

final class TodoDaySectionTests: XCTestCase {
    func testGroupingUsesLocalMidnightAndKeepsNewestFirstAcrossStatuses() throws {
        let formatter = ISO8601DateFormatter()
        let oldest = TodoItem(title: "Before midnight", createdAt: try XCTUnwrap(formatter.date(from: "2026-10-08T15:59:00Z")))
        let midnight = TodoItem(title: "Midnight", createdAt: try XCTUnwrap(formatter.date(from: "2026-10-08T16:00:00Z")), completedAt: .now)
        let newest = TodoItem(title: "Morning", createdAt: try XCTUnwrap(formatter.date(from: "2026-10-09T01:00:00Z")))
        let project = TodoProject(name: "Test", colorIndex: 0, tasks: [midnight, oldest, newest])
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let sections = TodoDaySection.grouping(sortedTasks: project.sortedTasks, calendar: calendar)
        XCTAssertEqual(sections.map { $0.tasks.map(\.id) }, [[newest.id, midnight.id], [oldest.id]])
        XCTAssertEqual(sections.map(\.date), [calendar.startOfDay(for: newest.createdAt), calendar.startOfDay(for: oldest.createdAt)])
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        XCTAssertEqual(TodoDaySection.grouping(sortedTasks: project.sortedTasks, calendar: calendar).map { $0.tasks.map(\.id) }, [[newest.id], [midnight.id, oldest.id]])
        XCTAssertTrue(TodoDaySection.grouping(sortedTasks: [], calendar: calendar).isEmpty)
    }

    func testRepeatedHourAtDaylightSavingBoundaryStaysInOneDay() throws {
        let formatter = ISO8601DateFormatter()
        let first = TodoItem(title: "First 1:30", createdAt: try XCTUnwrap(formatter.date(from: "2026-11-01T08:30:00Z")))
        let second = TodoItem(title: "Second 1:30", createdAt: try XCTUnwrap(formatter.date(from: "2026-11-01T09:30:00Z")))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let sections = TodoDaySection.grouping(sortedTasks: [second, first], calendar: calendar)
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.tasks.map(\.id), [second.id, first.id])
    }
}
