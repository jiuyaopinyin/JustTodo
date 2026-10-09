import AppKit
import SwiftUI
import TodoCore

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// Floating windows must accept the activation click as an actual interaction.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class DockCardHostingView: NSHostingView<ProjectDockCard> {
    var select: () -> Void = {}
    var copyText: () -> String = { "" }
    var drag: (CGSize) -> Void = { _ in }
    var drop: () -> Void = {}
    private var pressOrigin: NSPoint?
    private var didDrag = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var acceptsFirstResponder: Bool { true }
    @objc func copy(_ sender: Any?) { Clipboard.copy(copyText()) }
    override func shouldDelayWindowOrdering(for event: NSEvent) -> Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        pressOrigin = NSEvent.mouseLocation
        didDrag = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard let start = pressOrigin else { return }
        let mouse = NSEvent.mouseLocation
        let offset = CGSize(width: mouse.x - start.x, height: start.y - mouse.y)
        if hypot(offset.width, offset.height) >= 5 { didDrag = true }
        if didDrag { drag(offset) }
    }
    override func mouseUp(with event: NSEvent) {
        guard pressOrigin != nil else { return }
        pressOrigin = nil
        if didDrag { drop() } else { select() }
        didDrag = false
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = TodoStore()
    private var cards: [UUID: FloatingPanel] = [:]
    private var dragOrigins: [UUID: NSPoint] = [:]
    private var dragMouseOrigins: [UUID: NSPoint] = [:]
    private var cardsVisible = true
    private var detail: FloatingPanel!
    private var statusItem: NSStatusItem!
    private var clickMonitor: Any?
    private var contextMonitor: Any?
    private let settings = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Typography.registerDisplayFont()
        NSApp.setActivationPolicy(.accessory)
        buildWindows()
        buildMenu()
        buildEditingMenu()
        store.languageChanged = { [weak self] in self?.refreshLanguage() }
        NotificationCenter.default.addObserver(self, selector: #selector(systemLocaleChanged), name: NSLocale.currentLocaleDidChangeNotification, object: nil)
        // Dismiss explicitly without consuming a click destined for another card.
        settings.behavior = .applicationDefined
        settings.animates = false
        contextMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown, .keyDown]) { [weak self] event in
            let handled = MainActor.assumeIsolated {
                guard let self else { return false }
                if event.type == .keyDown {
                    if event.keyCode == 53 && self.detail.attachedSheet == nil && (self.settings.isShown || event.window === self.detail || self.cards.values.contains(where: { $0 === event.window })) {
                        self.settings.close()
                        self.detail.orderOut(nil)
                        return true
                    }
                    return false
                }
                if let id = self.cards.first(where: { $0.value === event.window })?.key {
                    if event.type == .rightMouseDown || event.modifierFlags.contains(.control) {
                        self.showSettings(id)
                        return true
                    }
                    self.settings.close()
                } else if event.window !== self.settings.contentViewController?.view.window {
                    self.settings.close()
                }
                return false
            }
            return handled ? nil : event
        }
        store.layoutChanged = { [weak self] in self?.syncCards() }
        NotificationCenter.default.addObserver(self, selector: #selector(positionWindows), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                if self?.detail.attachedSheet == nil { self?.detail.orderOut(nil) }
                self?.settings.close()
            }
        }
        syncCards()
        if let hintID = store.state.pendingSwipeHintTaskID,
           let project = store.state.projects.first(where: { $0.tasks.contains { $0.id == hintID } }) {
            showProject(project.id)
        }
    }

    private func panel(size: NSSize) -> FloatingPanel {
        let window = FloatingPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.isMovable = false
        window.animationBehavior = .utilityWindow
        return window
    }

    private func buildWindows() {
        detail = panel(size: NSSize(width: 396, height: 590))
        detail.title = store.t(.tasksWindow)
        detail.hasShadow = true
        detail.contentView = FirstClickHostingView(rootView: ProjectPanel(store: store, close: { [weak self] in self?.detail.orderOut(nil) }))
    }

    private func syncCards() {
        let projectIDs = Set(store.state.projects.map(\.id))
        for id in Array(cards.keys) where !projectIDs.contains(id) {
            cards.removeValue(forKey: id)?.close()
        }
        for project in store.state.projects where cards[project.id] == nil {
            let id = project.id
            let card = panel(size: DockMetrics.size(for: project.dockEdge ?? store.state.edge))
            card.title = store.t(.projectWindow, id.uuidString)
            card.hasShadow = false
            let select: () -> Void = { [weak self] in
                    guard let self else { return }
                    if self.store.selectedID == id && self.detail.isVisible { self.detail.orderOut(nil) }
                    else { self.showProject(id) }
            }
            let host = DockCardHostingView(rootView: ProjectDockCard(store: store, projectID: id, select: select))
            host.select = select
            host.copyText = { [weak self] in
                guard let project = self?.store.state.projects.first(where: { $0.id == id }) else { return "" }
                return project.completionSummary
            }
            host.drag = { [weak self] offset in self?.dragCard(id, translation: offset) }
            host.drop = { [weak self] in self?.dockCard(id) }
            card.contentView = host
            cards[id] = card
        }
        positionWindows()
        if cardsVisible { cards.values.forEach { $0.orderFrontRegardless() } }
    }

    private var displays: [DisplayArea] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            let displayID = CGDirectDisplayID(number.uint32Value)
            let identifier: String
            if let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() {
                identifier = CFUUIDCreateString(nil, uuid) as String
            } else {
                identifier = "display-\(displayID)"
            }
            return DisplayArea(id: identifier, frame: screen.frame, visibleFrame: screen.visibleFrame)
        }
    }

    @objc private func positionWindows() {
        let availableDisplays = displays
        guard !availableDisplays.isEmpty else { return }
        settings.close()
        for display in availableDisplays {
            let frame = display.visibleFrame
            for edge in ScreenEdge.allCases {
                let projects = store.state.projects.filter {
                    ($0.dockEdge ?? store.state.edge) == edge &&
                    DisplayLayout.resolve($0.displayID, in: availableDisplays)?.id == display.id
                }
                let size = DockMetrics.size(for: edge)
                let extent = edge == .top ? size.width : size.height
                let available = max(0, (edge == .top ? frame.width : frame.height) - extent)
                let spacing = min(extent + 10, available / CGFloat(max(1, projects.count - 1)))
                let total = spacing * CGFloat(max(0, projects.count - 1))
                for (index, project) in projects.enumerated() {
                    // Leave actively dragged cards under the cursor during screen changes.
                    guard dragOrigins[project.id] == nil else { continue }
                    let position = project.dockPosition ?? Double(((available - total) / 2 + CGFloat(index) * spacing) / max(1, available))
                    cards[project.id]?.setFrame(DisplayLayout.cardFrame(edge: edge, position: position, in: frame), display: true)
                }
            }
        }
        positionDetail()
    }

    private func showSettings(_ id: UUID) {
        guard let card = cards[id], let view = card.contentView,
              let project = store.state.projects.first(where: { $0.id == id }) else { return }
        settings.close()
        detail.orderOut(nil)
        settings.contentViewController = NSHostingController(rootView: DockSettings(store: store, projectID: id))
        settings.contentSize = DockSettings.size
        let edge: NSRectEdge
        switch project.dockEdge ?? store.state.edge {
        case .left: edge = .maxX
        case .right: edge = .minX
        case .top: edge = .minY
        }
        NSApp.activate(ignoringOtherApps: true)
        card.makeKeyAndOrderFront(nil)
        settings.show(relativeTo: view.bounds, of: view, preferredEdge: edge)
    }

    private func positionDetail() {
        guard let display = DisplayLayout.resolve(store.selectedProject?.displayID, in: displays) else { return }
        let frame = display.visibleFrame
        guard let project = store.selectedProject, let card = cards[project.id] else {
            detail.setFrameOrigin(NSPoint(x: frame.midX - 198, y: frame.midY - 295))
            return
        }
        detail.setFrameOrigin(DisplayLayout.detailOrigin(
            card: card.frame, edge: project.dockEdge ?? store.state.edge,
            size: detail.frame.size, in: frame))
    }

    private func dragCard(_ id: UUID, translation: CGSize) {
        guard let card = cards[id] else { return }
        if dragOrigins[id] == nil {
            settings.close()
            dragOrigins[id] = card.frame.origin
            let mouse = NSEvent.mouseLocation
            dragMouseOrigins[id] = NSPoint(x: mouse.x - translation.width, y: mouse.y + translation.height)
            detail.orderOut(nil)
        }
        guard let origin = dragOrigins[id], let start = dragMouseOrigins[id] else { return }
        let mouse = NSEvent.mouseLocation
        card.setFrameOrigin(NSPoint(x: origin.x + mouse.x - start.x, y: origin.y + mouse.y - start.y))
    }

    private func dockCard(_ id: UUID) {
        dragOrigins[id] = nil
        dragMouseOrigins[id] = nil
        guard let card = cards[id],
              let display = DisplayLayout.destination(at: NSEvent.mouseLocation, in: displays) else { return }
        let attachment = DisplayLayout.attachment(for: card.frame, in: display.visibleFrame)
        store.setDock(id, edge: attachment.edge, position: attachment.position, displayID: display.id)
    }

    private func showProject(_ id: UUID?) {
        settings.close()
        store.prepareDetail(for: id)
        cardsVisible = true
        cards.values.forEach { $0.orderFrontRegardless() }
        positionDetail()
        NSApp.activate(ignoringOtherApps: true)
        detail.makeKeyAndOrderFront(nil)
    }

    private func buildMenu() {
        if statusItem == nil { statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength) }
        statusItem.button?.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "JustTodo")
        let menu = NSMenu()
        menu.font = Typography.native(size: 13)
        menu.addItem(item(store.t(.toggleWindows), action: #selector(toggleWindows), key: ""))
        menu.addItem(item(store.t(.newProjectAction), action: #selector(newProject), key: ""))
        let languageItem = NSMenuItem(title: store.t(.language), action: nil, keyEquivalent: "")
        let languages = NSMenu(title: store.t(.language))
        languages.font = Typography.native(size: 13)
        for (language, title) in [(AppLanguage.system, store.t(.followSystem)), (.chinese, "中文"), (.english, "English")] {
            let option = item(title, action: #selector(changeLanguage(_:)), key: "")
            option.representedObject = language.rawValue
            option.state = store.language == language ? .on : .off
            languages.addItem(option)
        }
        languageItem.submenu = languages
        menu.addItem(languageItem)
        menu.addItem(.separator())
        menu.addItem(item(store.t(.quit), action: #selector(quit), key: "q"))
        statusItem.menu = menu
    }

    private func buildEditingMenu() {
        // Route standard shortcuts to the selected text or current text field.
        let main = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "JustTodo")
        applicationMenu.font = Typography.native(size: 13)
        applicationMenu.addItem(item(store.t(.quit), action: #selector(quit), key: "q"))
        applicationItem.submenu = applicationMenu
        main.addItem(applicationItem)
        let editingItem = NSMenuItem()
        let editingMenu = NSMenu(title: store.t(.editMenu))
        editingMenu.font = Typography.native(size: 13)
        let commands: [(TextKey, String, String)] = [(.cut, "cut:", "x"), (.copy, "copy:", "c"), (.paste, "paste:", "v"), (.selectAll, "selectAll:", "a")]
        for (title, selector, key) in commands {
            editingMenu.addItem(NSMenuItem(title: store.t(title), action: NSSelectorFromString(selector), keyEquivalent: key))
        }
        editingItem.submenu = editingMenu
        main.addItem(editingItem)
        NSApp.mainMenu = main
    }

    @objc private func changeLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let language = AppLanguage(rawValue: raw) else { return }
        store.setLanguage(language)
    }

    @objc private func systemLocaleChanged() { store.refreshSystemLanguage() }

    private func refreshLanguage() {
        buildMenu()
        buildEditingMenu()
        detail.title = store.t(.tasksWindow)
        for (id, card) in cards { card.title = store.t(.projectWindow, id.uuidString) }
    }

    private func item(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let result = NSMenuItem(title: title, action: action, keyEquivalent: key)
        result.target = self
        return result
    }

    @objc private func toggleWindows() {
        settings.close()
        cardsVisible.toggle()
        if cardsVisible { cards.values.forEach { $0.orderFrontRegardless() } }
        else { cards.values.forEach { $0.orderOut(nil) }; detail.orderOut(nil) }
    }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func newProject() {
        let alert = NSAlert()
        alert.messageText = store.t(.newProject)
        alert.informativeText = store.t(.nameProjectHint)
        alert.addButton(withTitle: store.t(.create))
        alert.addButton(withTitle: store.t(.cancel))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 26))
        field.placeholderString = store.t(.projectName)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        Typography.style(alert)
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            store.addProject(field.stringValue)
            showProject(store.selectedID)
        }
    }
}

@main
enum JustTodoMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
