import XCTest
@testable import TodoCore

final class LocalizationTests: XCTestCase {
    func testFreshProjectsHaveLocalizedPendingExamples() {
        let cases: [(AppLanguage, [String])] = [
            (.chinese, ["示例：记下一个突然想到的点子", "示例：左滑可编辑或删除待办", "示例：整理本周的工作计划", "示例：今晚散步 20 分钟"]),
            (.english, ["Example: Capture an idea that comes to mind", "Example: Swipe left to edit or delete a task", "Example: Plan this week's work", "Example: Take a 20-minute walk this evening"])
        ]
        for (language, titles) in cases {
            let state = TodoState(language: language)
            XCTAssertEqual(state.projects.map { $0.tasks.count }, [2, 1, 1])
            XCTAssertEqual(state.projects.flatMap(\.tasks).map(\.title), titles)
            XCTAssertEqual(state.projects.map(\.completionSummary), ["0/2", "0/1", "0/1"])
            XCTAssertEqual(Set(state.projects.flatMap(\.tasks).map(\.id)).count, 4)
            XCTAssertEqual(state.projects.first?.sortedTasks.first?.id, state.pendingSwipeHintTaskID)
        }
    }

    func testSystemLanguageResolutionAndFallback() {
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["zh-Hans-CN", "en-US"]), .chinese)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["zh_Hant_TW"]), .chinese)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["en-GB", "zh-Hans"]), .english)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["ja-JP", "zh-Hans"]), .chinese)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["fr-FR"]), .english)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: []), .english)
        XCTAssertEqual(AppLanguage.english.resolved(preferredLanguages: ["zh-Hans"]), .english)
        XCTAssertEqual(AppLanguage.chinese.resolved(preferredLanguages: ["en-US"]), .chinese)
    }

    func testBothLanguagesHaveMatchingFormatArguments() throws {
        let placeholders = try NSRegularExpression(pattern: "%(@|ld)")
        for key in TextKey.allCases {
            let zh = key.translation(in: .chinese)
            let en = key.translation(in: .english)
            XCTAssertFalse(zh.isEmpty, "Missing Chinese: \(key)")
            XCTAssertFalse(en.isEmpty, "Missing English: \(key)")
            func signature(_ text: String) -> [String] {
                let source = text as NSString
                return placeholders.matches(in: text, range: NSRange(location: 0, length: source.length))
                    .map { source.substring(with: $0.range) }
            }
            XCTAssertEqual(signature(zh), signature(en), "Format mismatch: \(key)")
        }
    }

    func testFormattedCountsAndUserText() {
        let en = Localizer(language: .english)
        let zh = Localizer(language: .chinese)
        XCTAssertEqual(en.format(.progressStatus, arguments: [2, 5, 3]), "2 of 5 completed, 3 remaining")
        XCTAssertEqual(zh.format(.progressStatus, arguments: [2, 5, 3]), "已完成 2 / 5，剩余 3")
        XCTAssertEqual(en.format(.addToProject, arguments: ["我的项目"]), "Add to “我的项目”")
    }

    func testLanguagePersistencePreservesExistingContent() throws {
        let project = TodoProject(name: "用户命名", colorIndex: 1, tasks: [TodoItem(title: "保留中文\nKeep English")])
        let state = TodoState(projects: [project], language: .english)
        let decoded = try JSONDecoder().decode(TodoState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.language, .english)
        XCTAssertEqual(decoded.projects, [project])
        XCTAssertEqual(TodoState(language: .english).projects.map(\.name), ["Inbox", "Work", "Personal"])
        XCTAssertEqual(TodoState(language: .chinese).projects.map(\.name), ["收集箱", "工作", "生活"])
    }
}
