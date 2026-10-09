import Foundation

public struct TodoItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var completedAt: Date?
    public var isCompleted: Bool { completedAt != nil }

    public init(id: UUID = UUID(), title: String, createdAt: Date = .now, completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    public mutating func toggle(at date: Date = .now) {
        completedAt = isCompleted ? nil : date
    }
}

public struct TodoProject: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var colorIndex: Int
    public var tasks: [TodoItem]
    public var dockEdge: ScreenEdge?
    public var dockPosition: Double?
    public var displayID: String?
    public var transparency: Double?
    public var effectiveTransparency: Double {
        guard let transparency, transparency.isFinite else { return 0.8 }
        return min(1, max(0, transparency))
    }

    public init(id: UUID = UUID(), name: String, colorIndex: Int, tasks: [TodoItem] = [], dockEdge: ScreenEdge? = nil, dockPosition: Double? = nil, transparency: Double? = nil, displayID: String? = nil) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.tasks = tasks
        self.dockEdge = dockEdge
        self.dockPosition = dockPosition
        self.displayID = displayID
        self.transparency = transparency
    }

    public var pendingCount: Int { tasks.filter { !$0.isCompleted }.count }
    public var completedCount: Int { tasks.count - pendingCount }
    public var completionSummary: String { "\(completedCount)/\(tasks.count)" }
    public var sortedTasks: [TodoItem] {
        tasks.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}

public enum ScreenEdge: String, Codable, CaseIterable, Sendable { case left, right, top }

public struct TodoState: Codable, Equatable, Sendable {
    public var projects: [TodoProject]
    public var edge: ScreenEdge
    public var language: AppLanguage?
    public var pendingSwipeHintTaskID: UUID?
    public init(projects: [TodoProject]? = nil, edge: ScreenEdge = .right, language: AppLanguage? = nil) {
        let localizer = Localizer(language: language ?? .system)
        let now = Date.now
        let swipeExample = TodoItem(title: localizer.text(.swipeExample), createdAt: now)
        self.projects = projects ?? [
            TodoProject(name: localizer.text(.inbox), colorIndex: 0,
                        tasks: [TodoItem(title: localizer.text(.inboxExample), createdAt: now.addingTimeInterval(-1)), swipeExample]),
            TodoProject(name: localizer.text(.work), colorIndex: 1,
                        tasks: [TodoItem(title: localizer.text(.workExample))]),
            TodoProject(name: localizer.text(.personal), colorIndex: 2,
                        tasks: [TodoItem(title: localizer.text(.personalExample))])
        ]
        self.edge = edge
        self.language = language
        self.pendingSwipeHintTaskID = projects == nil ? swipeExample.id : nil
    }

    /// Show the seeded swipe example once, without identifying tasks by editable text.
    public mutating func takeSwipeHint(in projectID: UUID?) -> UUID? {
        guard let taskID = pendingSwipeHintTaskID else { return nil }
        guard let project = projects.first(where: { $0.tasks.contains { $0.id == taskID && !$0.isCompleted } }) else {
            pendingSwipeHintTaskID = nil
            return nil
        }
        guard project.id == projectID else { return nil }
        pendingSwipeHintTaskID = nil
        return taskID
    }
}

public struct StateFile: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> TodoState {
        guard FileManager.default.fileExists(atPath: url.path) else { return TodoState() }
        return try JSONDecoder().decode(TodoState.self, from: Data(contentsOf: url))
    }
    public func save(_ state: TodoState) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: url, options: .atomic)
    }
}
