import AppKit
import SwiftUI
import TodoCore

@MainActor
final class TodoStore: ObservableObject {
    @Published private(set) var state: TodoState
    @Published var selectedID: UUID?
    @Published var detailPresentationID = UUID()
    @Published var revealedTaskID: UUID?
    private enum Failure { case load(String), save(String) }
    @Published private var failure: Failure?
    private let file: StateFile
    private var canSave = true
    var layoutChanged: (() -> Void)?
    var languageChanged: (() -> Void)?

    var language: AppLanguage { state.language ?? .system }
    var locale: Locale { Localizer(language: language).locale }
    func t(_ key: TextKey, _ arguments: CVarArg...) -> String {
        Localizer(language: language).format(key, arguments: arguments)
    }
    var errorMessage: String? {
        switch failure {
        case .load(let detail): return t(.loadError, detail)
        case .save(let detail): return t(.saveError, detail)
        case nil: return nil
        }
    }

    func setLanguage(_ language: AppLanguage) {
        state.language = language
        save()
        languageChanged?()
    }

    func refreshSystemLanguage() {
        objectWillChange.send()
        languageChanged?()
    }

    init() {
        // Keep the original data directory when renaming the app to JustTodo.
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EdgeTodo", isDirectory: true)
        file = StateFile(url: directory.appendingPathComponent("tasks.json"))
        do { state = try file.load() }
        catch {
            state = TodoState()
            canSave = false
            failure = .load(error.localizedDescription)
        }
        selectedID = state.projects.first?.id
    }

    var selectedProject: TodoProject? { state.projects.first { $0.id == selectedID } }
    var pendingCount: Int { state.projects.reduce(0) { $0 + $1.pendingCount } }

    func prepareDetail(for projectID: UUID?) {
        selectedID = projectID
        let previousHint = state.pendingSwipeHintTaskID
        revealedTaskID = state.takeSwipeHint(in: projectID)
        detailPresentationID = UUID()
        if previousHint != state.pendingSwipeHintTaskID { save() }
    }

    private func save() {
        guard canSave else { return }
        do { try file.save(state) }
        catch { failure = .save(error.localizedDescription) }
    }

    func setEdge(_ edge: ScreenEdge) {
        state.edge = edge
        for index in state.projects.indices {
            state.projects[index].dockEdge = edge
            state.projects[index].dockPosition = nil
        }
        save()
        layoutChanged?()
    }

    func setDock(_ id: UUID, edge: ScreenEdge, position: Double? = nil, displayID: String? = nil) {
        guard let index = state.projects.firstIndex(where: { $0.id == id }) else { return }
        state.projects[index].dockEdge = edge
        state.projects[index].dockPosition = position.map { min(1, max(0, $0)) }
        if let displayID { state.projects[index].displayID = displayID }
        save()
        layoutChanged?()
    }

    func addProject(_ name: String) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        let project = TodoProject(name: cleaned, colorIndex: state.projects.count % Theme.colors.count)
        state.projects.append(project)
        selectedID = project.id
        save()
        layoutChanged?()
    }

    func setColor(_ id: UUID, index: Int) {
        guard Theme.colors.indices.contains(index),
              let projectIndex = state.projects.firstIndex(where: { $0.id == id }) else { return }
        state.projects[projectIndex].colorIndex = index
        save()
    }

    func setTransparency(_ id: UUID, value: Double) {
        guard value.isFinite, let index = state.projects.firstIndex(where: { $0.id == id }) else { return }
        state.projects[index].transparency = min(1, max(0, value))
        save()
    }

    func renameProject(_ id: UUID, name: String) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let index = state.projects.firstIndex(where: { $0.id == id }) else { return }
        state.projects[index].name = cleaned
        save()
    }

    func deleteProject(_ id: UUID) {
        state.projects.removeAll { $0.id == id }
        if selectedID == id { selectedID = state.projects.first?.id }
        save()
        layoutChanged?()
    }

    @discardableResult
    func addTask(_ title: String, to projectID: UUID? = nil) -> Bool {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let index = state.projects.firstIndex(where: { $0.id == (projectID ?? selectedID) }) else { return false }
        state.projects[index].tasks.append(TodoItem(title: cleaned))
        save()
        return true
    }

    @discardableResult
    func toggleTask(_ id: UUID) -> Bool {
        guard let p = state.projects.firstIndex(where: { $0.id == selectedID }),
              let t = state.projects[p].tasks.firstIndex(where: { $0.id == id }) else { return false }
        state.projects[p].tasks[t].toggle()
        let completed = state.projects[p].tasks[t].isCompleted
        save()
        return completed
    }

    func editTask(_ id: UUID, title: String, in projectID: UUID? = nil) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let p = state.projects.firstIndex(where: { $0.id == (projectID ?? selectedID) }),
              let t = state.projects[p].tasks.firstIndex(where: { $0.id == id }) else { return }
        state.projects[p].tasks[t].title = cleaned
        save()
    }

    func deleteTask(_ id: UUID) {
        guard let p = state.projects.firstIndex(where: { $0.id == selectedID }) else { return }
        state.projects[p].tasks.removeAll { $0.id == id }
        save()
    }
}
