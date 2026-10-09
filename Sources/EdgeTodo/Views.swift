import SwiftUI
import TodoCore

@MainActor
enum Clipboard {
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

enum Theme {
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let ink = Color(red: 0.17, green: 0.20, blue: 0.19)
    static let muted = Color(red: 0.49, green: 0.51, blue: 0.47)
    // Keep the original five index meanings so existing projects retain their color family.
    static let colors: [Color] = [.red, .green, .blue, .orange, .purple, .yellow, .gray]
    static let colorKeys: [TextKey] = [.red, .green, .blue, .orange, .purple, .yellow, .gray]
    static let tagOrder = [0, 3, 5, 1, 2, 4, 6]
    static func color(_ index: Int) -> Color { colors[((index % colors.count) + colors.count) % colors.count] }

    static func dockNumberColor(_ index: Int, transparency: Double) -> Color {
        let tint = color(index)
        guard transparency < 0.65 else { return tint }
        var rgb = NSColor(tint)
        NSAppearance(named: .aqua)?.performAsCurrentDrawingAppearance {
            rgb = NSColor(tint).usingColorSpace(.sRGB) ?? .black
        }
        // Estimate the composited light background and choose the higher-contrast text.
        func linear(_ channel: CGFloat) -> Double {
            let value = Double(channel) * (1 - transparency) + transparency
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(rgb.redComponent)
            + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
        return luminance > 0.179 ? .black : .white
    }

}

enum DockMetrics {
    static func size(for edge: ScreenEdge) -> NSSize {
        DisplayLayout.cardSize(for: edge)
    }
}

// A rectangular card with only the exposed end rounded.
struct DockCardShape: Shape {
    var edge: ScreenEdge
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let radii = RectangleCornerRadii(
            topLeading: edge == .right ? radius : 0,
            bottomLeading: edge == .left ? 0 : radius,
            bottomTrailing: edge == .right ? 0 : radius,
            topTrailing: edge == .left ? radius : 0
        )
        return UnevenRoundedRectangle(cornerRadii: radii, style: .circular).path(in: rect)
    }
}

struct ProjectDockCard: View {
    @ObservedObject var store: TodoStore
    let projectID: UUID
    var select: () -> Void
    @State private var hovering = false

    var body: some View {
        if let project = store.state.projects.first(where: { $0.id == projectID }) {
            let edge = project.dockEdge ?? store.state.edge
            let color = Theme.color(project.colorIndex)
            let size = DockMetrics.size(for: edge)
            ZStack {
                DockCardShape(edge: edge).fill(color.opacity(1 - project.effectiveTransparency))
                if hovering {
                    DockCardShape(edge: edge).stroke(color.opacity(0.5), lineWidth: 0.5)
                }
                Text(project.completionSummary)
                    .font(Typography.dockNumber(size: 17))
                    .foregroundStyle(Theme.dockNumberColor(project.colorIndex, transparency: project.effectiveTransparency))
                    .lineLimit(1).minimumScaleFactor(0.4)
                    .padding(6)
            }
            .frame(width: size.width, height: size.height)
            .contentShape(DockCardShape(edge: edge))
            .onHover { hovering = $0 }
            .help(store.t(.dockHelp, project.name, project.completedCount, project.tasks.count))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(store.t(.dockStatus, project.name, project.completedCount, project.tasks.count))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { select() }
            .preferredColorScheme(.light)
        }
    }
}

struct DockSettings: View {
    static let size = NSSize(width: 240, height: 118)
    @ObservedObject var store: TodoStore
    let projectID: UUID
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        if let project = store.state.projects.first(where: { $0.id == projectID }) {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    ForEach(Theme.tagOrder, id: \.self) { index in
                        Button { store.setColor(projectID, index: index) } label: {
                            ZStack {
                                Circle().fill(Theme.colors[index]).frame(width: 12, height: 12)
                                if project.colorIndex == index {
                                    Circle().strokeBorder(Theme.colors[index], lineWidth: 1)
                                        .frame(width: 18, height: 18)
                                }
                            }.frame(width: 18, height: 20).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).help(store.t(Theme.colorKeys[index]))
                        .accessibilityLabel(store.t(Theme.colorKeys[index]))
                        .accessibilityAddTraits(project.colorIndex == index ? .isSelected : [])
                    }
                }
                HStack(spacing: 6) {
                    Slider(value: Binding(
                        get: { project.effectiveTransparency },
                        set: { store.setTransparency(projectID, value: ($0 * 100).rounded() / 100) }
                    ), in: 0...1)
                    .controlSize(.mini)
                    .accessibilityLabel(store.t(.transparency))
                    .help(store.t(.transparencyHint))
                    Text("\(Int((project.effectiveTransparency * 100).rounded()))%")
                        .font(Typography.font(size: 9)).monospacedDigit().foregroundStyle(.secondary)
                        .frame(width: 28)
                        .textSelection(.enabled)
                }
                HStack(spacing: 8) {
                    TextField(store.t(.addPlaceholder), text: $draft)
                        .textFieldStyle(.plain)
                        .font(Typography.font(size: 12))
                        .focused($inputFocused)
                        .onSubmit(submit)
                        .accessibilityLabel(store.t(.newTask))
                        .padding(7)
                        .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
                    Button(store.t(.add), action: submit)
                        .font(Typography.font(size: 12, weight: .medium))
                        .buttonStyle(.plain)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .help(store.t(.addToProject, project.name))
                }
            }
            .padding(12).frame(width: Self.size.width, height: Self.size.height)
            .environment(\.locale, store.locale)
            .task { inputFocused = true }
        }
    }

    private func submit() {
        guard store.addTask(draft, to: projectID) else { return }
        draft = ""
        inputFocused = true
    }
}

enum TaskFilter: CaseIterable {
    case pending, completed, all

    var key: TextKey {
        switch self {
        case .pending: .pending
        case .completed: .completed
        case .all: .allTasks
        }
    }

    var emptyKey: TextKey {
        switch self {
        case .pending: .emptyPending
        case .completed: .emptyCompleted
        case .all: .emptyTasks
        }
    }

    func includes(_ task: TodoItem) -> Bool {
        switch self {
        case .pending: !task.isCompleted
        case .completed: task.isCompleted
        case .all: true
        }
    }
}

struct ProjectPanel: View {
    @ObservedObject var store: TodoStore
    var close: () -> Void
    @State private var filter: TaskFilter = .pending
    @State private var draft = ""
    @State private var projectName = ""
    @State private var showNewProject = false
    @State private var showRename = false
    @State private var showDelete = false
    @State private var editingTask: TaskEditDraft?
    @State private var celebrationID: UUID?
    @State private var celebrationOrigin = CGPoint.zero
    @FocusState private var inputFocused: Bool

    private var accent: Color { Theme.color(store.selectedProject?.colorIndex ?? 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                if let project = store.selectedProject {
                    progressRing(project)
                    Text(project.name).font(Typography.font(size: 20, weight: .semibold)).lineLimit(2)
                        .padding(.top, 7)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 8)
                Menu {
                    Button(store.t(.newProjectAction)) { projectName = ""; showNewProject = true }
                    if let project = store.selectedProject {
                        Button(store.t(.renameProjectAction)) { projectName = project.name; showRename = true }
                        Button(store.t(.deleteProjectAction), role: .destructive) { showDelete = true }
                    }
                    Divider()
                    Picker(store.t(.language), selection: Binding(get: { store.language }, set: { store.setLanguage($0) })) {
                        Text(store.t(.followSystem)).tag(AppLanguage.system)
                        Text("中文").tag(AppLanguage.chinese)
                        Text("English").tag(AppLanguage.english)
                    }
                    Divider()
                    Button(store.t(.hide)) { close() }
                } label: {
                    Image(systemName: "ellipsis").font(Typography.font(size: 16, weight: .medium))
                        .frame(width: 24, height: 40)
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .foregroundStyle(Theme.ink.opacity(0.6)).accessibilityLabel(store.t(.more)).help(store.t(.more))
            }.padding(.bottom, 12)

            if let project = store.selectedProject {
                HStack {
                    Spacer(minLength: 0)
                    Menu {
                        ForEach(TaskFilter.allCases, id: \.self) { value in
                            Button { filter = value } label: {
                                if filter == value {
                                    Label(store.t(value.key), systemImage: "checkmark")
                                } else {
                                    Text(store.t(value.key))
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(store.t(filter.key)).font(Typography.font(size: 11))
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(Typography.font(size: 13, weight: .medium))
                        }
                        .padding(.vertical, 7).contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .foregroundStyle(Theme.ink.opacity(0.6))
                    .accessibilityLabel(store.t(.filterTasks))
                    .accessibilityValue(store.t(filter.key))
                    .help("\(store.t(.filterTasks)): \(store.t(filter.key))")
                }.padding(.bottom, 4)

                let tasks = project.sortedTasks.filter { filter.includes($0) }
                // Refresh the day boundary while the panel stays open overnight.
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    let calendar = Calendar.current
                    let sections = TodoDaySection.grouping(sortedTasks: tasks, calendar: calendar)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if tasks.isEmpty {
                                Text(store.t(filter.emptyKey))
                                    .font(Typography.font(size: 12)).foregroundStyle(Theme.ink.opacity(0.4))
                                    .frame(maxWidth: .infinity).padding(.vertical, 55)
                                    .textSelection(.enabled)
                            }
                            ForEach(sections) { section in
                                if !calendar.isDate(section.date, inSameDayAs: timeline.date) {
                                    Text(section.date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).locale(store.locale)))
                                        .font(Typography.font(size: 10, weight: .medium))
                                        .foregroundStyle(Theme.ink.opacity(0.45))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.top, 16).padding(.bottom, 5)
                                }
                                ForEach(section.tasks) { task in taskRow(task) }
                            }
                        }
                        .padding(.bottom, 12)
                    }.scrollIndicators(.hidden)
                }

                TextField(store.t(.addPlaceholder), text: $draft)
                    .textFieldStyle(.plain).font(Typography.font(size: 13))
                    .focused($inputFocused).onSubmit(submit)
                    .accessibilityLabel(store.t(.newTask))
                    .padding(13)
                    .background(.white.opacity(0.6))
            } else {
                Spacer()
                Button(store.t(.createProject)) { projectName = ""; showNewProject = true }
                Spacer()
            }
            if let error = store.errorMessage {
                Text(error).font(Typography.font(size: 11)).foregroundStyle(.red).padding(.top, 8).textSelection(.enabled)
            }
        }
        .padding(24).frame(width: 396, height: 590)
        .coordinateSpace(name: "projectPanel")
        .foregroundStyle(Theme.ink)
        .background { Color.white.overlay(accent.opacity(0.16)) }
        .overlay {
            if let celebrationID {
                CompletionConfetti(origin: celebrationOrigin).id(celebrationID)
                    .allowsHitTesting(false)
            }
        }
        .clipped()
        .task(id: celebrationID) {
            guard let current = celebrationID else { return }
            do { try await Task.sleep(for: .seconds(CompletionConfetti.duration)) }
            catch { return }
            if celebrationID == current { celebrationID = nil }
        }
        .preferredColorScheme(.light)
        .font(Typography.font(size: 13))
        .environment(\.locale, store.locale)
        .alert(store.t(.newProject), isPresented: $showNewProject) {
            TextField(store.t(.projectName), text: $projectName)
            Button(store.t(.cancel), role: .cancel) {}
            Button(store.t(.create)) { store.addProject(projectName) }
        }
        .alert(store.t(.renameProject), isPresented: $showRename) {
            TextField(store.t(.projectName), text: $projectName)
            Button(store.t(.cancel), role: .cancel) {}
            Button(store.t(.save)) { if let id = store.selectedID { store.renameProject(id, name: projectName) } }
        }
        .alert(store.t(.deleteProjectQuestion), isPresented: $showDelete) {
            Button(store.t(.cancel), role: .cancel) {}
            Button(store.t(.delete), role: .destructive) { if let id = store.selectedID { store.deleteProject(id) } }
        } message: { Text(store.t(.deleteProjectWarning)) }
        .sheet(item: $editingTask) { task in
            TaskEditor(store: store, initialText: task.title, cancel: { editingTask = nil }, save: { text in
                store.editTask(task.id, title: text, in: task.projectID)
                editingTask = nil
            })
        }
        .onChange(of: store.detailPresentationID) { _, _ in draft = ""; filter = .pending; celebrationID = nil }
        .onChange(of: store.selectedID) { _, _ in
            draft = ""; filter = .pending; celebrationID = nil
            if store.selectedProject?.tasks.contains(where: { $0.id == store.revealedTaskID }) != true {
                store.revealedTaskID = nil
            }
        }
        .onChange(of: filter) { _, _ in store.revealedTaskID = nil }
        .onExitCommand { if editingTask != nil { editingTask = nil } else { close() } }
        .background(Button("") { inputFocused = true }.keyboardShortcut("n", modifiers: .command).hidden())
    }

    private func progressRing(_ project: TodoProject) -> some View {
        ZStack {
            Circle().stroke(accent.opacity(0.15), lineWidth: 2.5)
            Circle().trim(from: 0, to: CGFloat(project.completedCount) / CGFloat(max(1, project.tasks.count)))
                .stroke(accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(project.completionSummary)
                .font(Typography.font(size: 11, weight: .medium)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5)
                .padding(4).textSelection(.enabled)
        }
        .frame(width: 40, height: 40)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(store.t(.progress))
        .accessibilityValue(store.t(.progressStatus, project.completedCount, project.tasks.count, project.pendingCount))
        .help(store.t(.progressHint, project.completedCount, project.tasks.count))
    }

    private func submit() {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        store.addTask(draft)
        draft = ""
        if filter == .completed { filter = .pending }
        inputFocused = true
    }

    private func beginEditing(_ task: TodoItem) {
        guard let projectID = store.selectedID else { return }
        store.revealedTaskID = nil
        editingTask = TaskEditDraft(id: task.id, projectID: projectID, title: task.title)
    }

    private func taskRow(_ task: TodoItem) -> some View {
        return SwipeableTaskRow(
            id: task.id, revealedID: $store.revealedTaskID,
            editTitle: store.t(.editMenu), deleteTitle: store.t(.delete),
            showActionsTitle: store.t(.showTaskActions), hideActionsTitle: store.t(.hideTaskActions),
            background: accent.opacity(0.16),
            edit: { beginEditing(task) }, delete: { store.deleteTask(task.id) }
        ) {
        HStack(alignment: .top, spacing: 10) {
            GeometryReader { geometry in
                Button {
                    // Capture before toggling: the To do filter immediately removes this row.
                    let frame = geometry.frame(in: .named("projectPanel"))
                    let origin = CGPoint(x: frame.midX, y: frame.midY)
                    if store.toggleTask(task.id) {
                        celebrationOrigin = origin
                        celebrationID = UUID()
                    }
                } label: {
                ZStack {
                    Circle().strokeBorder(Theme.ink.opacity(task.isCompleted ? 0.15 : 0.3), lineWidth: 1)
                    if task.isCompleted {
                        Image(systemName: "checkmark").font(Typography.font(size: 9, weight: .medium)).foregroundStyle(Theme.ink.opacity(0.45))
                    }
                }.frame(width: 16, height: 16)
                    .padding(.vertical, 2).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(store.t(task.isCompleted ? .restorePending : .markCompleted))
                .accessibilityLabel(store.t(task.isCompleted ? .taskCompletedStatus : .taskPendingStatus, task.title))
            }.frame(width: 16, height: 20)

            ExpandableTaskBody(store: store, text: task.title, isCompleted: task.isCompleted)

            Text(task.createdAt.formatted(.dateTime.hour().minute().locale(store.locale)))
                .font(Typography.font(size: 9))
                .foregroundStyle(Theme.ink.opacity(0.4))
                .fixedSize().padding(.top, 3)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        }
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.ink.opacity(0.05)).frame(height: 1).padding(.leading, 26) }
    }
}
