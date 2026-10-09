import Foundation

public struct TodoDaySection: Identifiable, Sendable {
    public let date: Date
    public let tasks: [TodoItem]
    public var id: Date { date }

    // Keep the incoming task order within each day (the project's newest-first order).
    public static func grouping(sortedTasks: [TodoItem], calendar: Calendar = .current) -> [TodoDaySection] {
        let days = Dictionary(grouping: sortedTasks) { calendar.startOfDay(for: $0.createdAt) }
        return days.keys.sorted(by: >).map { TodoDaySection(date: $0, tasks: days[$0]!) }
    }
}
