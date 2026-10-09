import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case system, chinese, english

    public func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        for identifier in preferredLanguages {
            let language = identifier.lowercased().replacingOccurrences(of: "_", with: "-").split(separator: "-").first
            if language == "zh" { return .chinese }
            if language == "en" { return .english }
        }
        return .english
    }
}

public enum TextKey: CaseIterable, Sendable {
    case language
    case followSystem
    case red
    case green
    case blue
    case orange
    case purple
    case yellow
    case gray
    case dockHelp
    case dockStatus
    case transparency
    case transparencyHint
    case addTodo
    case pending
    case completed
    case allTasks
    case filterTasks
    case newProjectAction
    case renameProjectAction
    case deleteProjectAction
    case hide
    case more
    case copy
    case progress
    case progressStatus
    case progressHint
    case emptyPending
    case emptyCompleted
    case emptyTasks
    case addPlaceholder
    case newTask
    case createProject
    case newProject
    case projectName
    case cancel
    case create
    case renameProject
    case save
    case deleteProjectQuestion
    case delete
    case deleteProjectWarning
    case restorePending
    case markCompleted
    case taskCompletedStatus
    case taskPendingStatus
    case copyTask
    case copyDate
    case editAction
    case showTaskActions
    case hideTaskActions
    case deleteTask
    case editTask
    case taskContent
    case collapse
    case expand
    case collapseHint
    case expandHint
    case expanded
    case collapsed
    case loadError
    case saveError
    case tasksWindow
    case projectWindow
    case toggleWindows
    case quit
    case editMenu
    case cut
    case paste
    case selectAll
    case addToProject
    case add
    case nameProjectHint
    case inbox
    case work
    case personal
    case inboxExample
    case swipeExample
    case workExample
    case personalExample

    public func translation(in language: AppLanguage) -> String {
        let pair: (String, String)
        switch self {
        case .language: pair = ("语言", "Language")
        case .followSystem: pair = ("跟随系统", "Follow System")
        case .red: pair = ("红色", "Red")
        case .green: pair = ("绿色", "Green")
        case .blue: pair = ("蓝色", "Blue")
        case .orange: pair = ("橙色", "Orange")
        case .purple: pair = ("紫色", "Purple")
        case .yellow: pair = ("黄色", "Yellow")
        case .gray: pair = ("灰色", "Gray")
        case .dockHelp: pair = ("%@ · 已完成 %ld / 共 %ld 项；拖动贴边，右键设置颜色和透明度", "%@ · %ld of %ld completed. Drag to dock; right-click for color and transparency.")
        case .dockStatus: pair = ("%@，已完成 %ld 项，共 %ld 项", "%@, %ld of %ld completed")
        case .transparency: pair = ("背景透明度", "Background transparency")
        case .transparencyHint: pair = ("向右更透明；数字保持清晰", "Move right for more transparency; numbers stay legible.")
        case .addTodo: pair = ("添加待办", "Add to-do")
        case .pending: pair = ("未完成", "To do")
        case .completed: pair = ("已完成", "Done")
        case .allTasks: pair = ("全部", "All")
        case .filterTasks: pair = ("筛选任务", "Filter Tasks")
        case .newProjectAction: pair = ("新建项目…", "New Project…")
        case .renameProjectAction: pair = ("重命名项目…", "Rename Project…")
        case .deleteProjectAction: pair = ("删除项目…", "Delete Project…")
        case .hide: pair = ("收起", "Hide")
        case .more: pair = ("更多", "More")
        case .copy: pair = ("复制", "Copy")
        case .progress: pair = ("完成进度", "Completion progress")
        case .progressStatus: pair = ("已完成 %ld / %ld，剩余 %ld", "%ld of %ld completed, %ld remaining")
        case .progressHint: pair = ("已完成 %ld / %ld", "%ld of %ld completed")
        case .emptyPending: pair = ("暂无未完成任务", "No pending tasks")
        case .emptyCompleted: pair = ("暂无已完成任务", "No completed tasks")
        case .emptyTasks: pair = ("暂无任务", "No tasks yet")
        case .addPlaceholder: pair = ("添加任务…", "Add a task…")
        case .newTask: pair = ("新任务", "New task")
        case .createProject: pair = ("创建项目", "Create Project")
        case .newProject: pair = ("新建项目", "New Project")
        case .projectName: pair = ("项目名称", "Project name")
        case .cancel: pair = ("取消", "Cancel")
        case .create: pair = ("创建", "Create")
        case .renameProject: pair = ("重命名项目", "Rename Project")
        case .save: pair = ("保存", "Save")
        case .deleteProjectQuestion: pair = ("删除这个项目？", "Delete this project?")
        case .delete: pair = ("删除", "Delete")
        case .deleteProjectWarning: pair = ("项目中的所有任务也会一起删除，此操作无法撤销。", "All tasks in this project will also be deleted. This cannot be undone.")
        case .restorePending: pair = ("恢复为未完成", "Mark as To Do")
        case .markCompleted: pair = ("标记为完成", "Mark as Done")
        case .taskCompletedStatus: pair = ("%@，已完成，点击恢复", "%@, completed; click to restore")
        case .taskPendingStatus: pair = ("%@，未完成，点击完成", "%@, pending; click to complete")
        case .copyTask: pair = ("复制任务内容", "Copy Task Text")
        case .copyDate: pair = ("复制日期", "Copy Date")
        case .editAction: pair = ("编辑…", "Edit…")
        case .showTaskActions: pair = ("显示编辑和删除按钮", "Show Edit and Delete")
        case .hideTaskActions: pair = ("收起操作按钮", "Hide Actions")
        case .deleteTask: pair = ("删除任务", "Delete Task")
        case .editTask: pair = ("编辑待办", "Edit To-do")
        case .taskContent: pair = ("待办内容", "To-do text")
        case .collapse: pair = ("收起", "Collapse")
        case .expand: pair = ("展开", "Expand")
        case .collapseHint: pair = ("收起为最多 5 行", "Collapse to 5 lines")
        case .expandHint: pair = ("展开完整内容", "Show full text")
        case .expanded: pair = ("已展开", "Expanded")
        case .collapsed: pair = ("已收起", "Collapsed")
        case .loadError: pair = ("无法读取已有数据，为保护原文件，本次不会覆盖保存。\n%@", "Could not read your data. The original file will not be overwritten.\n%@")
        case .saveError: pair = ("保存失败：%@", "Could not save: %@")
        case .tasksWindow: pair = ("JustTodo 任务", "JustTodo Tasks")
        case .projectWindow: pair = ("JustTodo 项目 %@", "JustTodo Project %@")
        case .toggleWindows: pair = ("显示 / 隐藏待办", "Show / Hide To-dos")
        case .quit: pair = ("退出 JustTodo", "Quit JustTodo")
        case .editMenu: pair = ("编辑", "Edit")
        case .cut: pair = ("剪切", "Cut")
        case .paste: pair = ("粘贴", "Paste")
        case .selectAll: pair = ("全选", "Select All")
        case .addToProject: pair = ("添加到「%@」", "Add to “%@”")
        case .add: pair = ("添加", "Add")
        case .nameProjectHint: pair = ("给这个项目取一个名字。", "Give this project a name.")
        case .inbox: pair = ("收集箱", "Inbox")
        case .work: pair = ("工作", "Work")
        case .personal: pair = ("生活", "Personal")
        case .inboxExample: pair = ("示例：记下一个突然想到的点子", "Example: Capture an idea that comes to mind")
        case .swipeExample: pair = ("示例：左滑可编辑或删除待办", "Example: Swipe left to edit or delete a task")
        case .workExample: pair = ("示例：整理本周的工作计划", "Example: Plan this week's work")
        case .personalExample: pair = ("示例：今晚散步 20 分钟", "Example: Take a 20-minute walk this evening")
        }
        return language.resolved() == .chinese ? pair.0 : pair.1
    }
}

public struct Localizer: Sendable {
    public let language: AppLanguage
    public var locale: Locale { Locale(identifier: language == .chinese ? "zh-Hans" : "en") }

    public init(language: AppLanguage = .system, preferredLanguages: [String] = Locale.preferredLanguages) {
        self.language = language.resolved(preferredLanguages: preferredLanguages)
    }
    public func text(_ key: TextKey) -> String { key.translation(in: language) }
    public func format(_ key: TextKey, arguments: [CVarArg]) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }
}
