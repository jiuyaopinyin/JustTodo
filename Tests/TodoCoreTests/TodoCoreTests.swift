import XCTest
@testable import TodoCore

final class TodoCoreTests: XCTestCase {
    func testLegacyProjectsDecodeWithoutDockSettings() throws {
        let json = """
        {"edge":"right","projects":[{"id":"00000000-0000-0000-0000-000000000001","name":"旧项目","colorIndex":0,"tasks":[]}]}
        """
        let state = try JSONDecoder().decode(TodoState.self, from: Data(json.utf8))
        XCTAssertEqual(state.projects.first?.name, "旧项目")
        XCTAssertEqual(state.projects.first?.tasks, [])
        XCTAssertNil(state.projects.first?.dockEdge)
        XCTAssertNil(state.projects.first?.dockPosition)
        XCTAssertNil(state.projects.first?.displayID)
        XCTAssertEqual(state.projects.first?.effectiveTransparency, 0.8)
        XCTAssertEqual(state.edge, .right)
        XCTAssertNil(state.language)
        XCTAssertNil(state.pendingSwipeHintTaskID)
    }

    func testIndependentDockPositionsSurviveRestart() throws {
        let projects = [
            TodoProject(name: "左", colorIndex: 0, dockEdge: .left, dockPosition: 0.2, transparency: 0.35),
            TodoProject(name: "右", colorIndex: 1, dockEdge: .right, dockPosition: 0.7, transparency: 1),
            TodoProject(name: "上", colorIndex: 2, dockEdge: .top, dockPosition: 0.5)
        ]
        let state = TodoState(projects: projects)
        let decoded = try JSONDecoder().decode(TodoState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded, state)
    }

    func testNewestCreatedFirstRegardlessOfCompletion() {
        let old = TodoItem(title: "旧待办", createdAt: Date(timeIntervalSince1970: 1))
        let new = TodoItem(title: "新待办", createdAt: Date(timeIntervalSince1970: 2))
        let done = TodoItem(title: "已完成", createdAt: Date(timeIntervalSince1970: 3), completedAt: .now)
        let project = TodoProject(name: "工作", colorIndex: 0, tasks: [done, old, new])
        XCTAssertEqual(project.sortedTasks.map(\.id), [done.id, new.id, old.id])
        XCTAssertEqual(project.sortedTasks.filter { !$0.isCompleted }.map(\.id), [new.id, old.id])
        XCTAssertEqual(project.pendingCount, 2)
    }

    func testToggleRestoresTaskWithoutChangingCreationDate() {
        var task = TodoItem(title: "可恢复")
        let created = task.createdAt
        task.toggle(at: Date(timeIntervalSince1970: 50))
        XCTAssertTrue(task.isCompleted)
        XCTAssertEqual(task.completedAt, Date(timeIntervalSince1970: 50))
        task.toggle()
        XCTAssertFalse(task.isCompleted)
        XCTAssertEqual(task.createdAt, created)
    }

    func testPersistenceRoundTripAndMissingFileDefaults() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = StateFile(url: directory.appendingPathComponent("nested/tasks.json"))
        let initial = try file.load()
        XCTAssertEqual(initial.projects.count, 3)
        XCTAssertEqual(initial.projects.map { $0.tasks.count }, [2, 1, 1])
        try file.save(initial)
        XCTAssertEqual(try file.load(), initial)
        var cleared = initial
        for index in cleared.projects.indices { cleared.projects[index].tasks = [] }
        try file.save(cleared)
        XCTAssertEqual(try file.load(), cleared, "Deleted examples must not return on restart")
        var task = TodoItem(title: "中文任务 🌱")
        task.toggle()
        let state = TodoState(projects: [TodoProject(name: "测试", colorIndex: 2, tasks: [task])], edge: .left)
        try file.save(state)
        XCTAssertEqual(try file.load(), state)
        try file.save(TodoState(projects: [], edge: .right))
        XCTAssertEqual(try file.load().projects, [])
    }

    func testCorruptDataThrowsInsteadOfResetting() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("broken".utf8).write(to: url)
        XCTAssertThrowsError(try StateFile(url: url).load())
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "broken")
    }

    func testSwipeHintIsOnlyConsumedForItsProjectAndStaysConsumedAfterReload() throws {
        var state = TodoState(language: .chinese)
        let hint = try XCTUnwrap(state.pendingSwipeHintTaskID)
        XCTAssertNil(state.takeSwipeHint(in: state.projects[1].id))
        XCTAssertEqual(state.pendingSwipeHintTaskID, hint)
        XCTAssertEqual(state.takeSwipeHint(in: state.projects[0].id), hint)
        XCTAssertNil(state.takeSwipeHint(in: state.projects[0].id))
        var restored = try JSONDecoder().decode(TodoState.self, from: JSONEncoder().encode(state))
        XCTAssertNil(restored.takeSwipeHint(in: restored.projects[0].id))
        XCTAssertEqual(restored.projects[0].tasks.count, 2)
    }

    func testMissingSwipeExampleDoesNotReappearOrTriggerHint() {
        var state = TodoState()
        let hint = state.pendingSwipeHintTaskID
        state.projects[0].tasks.removeAll { $0.id == hint }
        XCTAssertNil(state.takeSwipeHint(in: state.projects[0].id))
        XCTAssertNil(state.pendingSwipeHintTaskID)
        XCTAssertEqual(state.projects[0].tasks.count, 1)
        XCTAssertNil(TodoState(projects: []).pendingSwipeHintTaskID)
    }
}
