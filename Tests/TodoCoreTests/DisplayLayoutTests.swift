import XCTest
import CoreGraphics
@testable import TodoCore

final class DisplayLayoutTests: XCTestCase {
    private let main = DisplayArea(id: "built-in", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 40, width: 1440, height: 836))
    private let left = DisplayArea(id: "external", frame: CGRect(x: -1920, y: -200, width: 1920, height: 1080), visibleFrame: CGRect(x: -1920, y: -160, width: 1920, height: 1016))

    func testDragDestinationAcrossNegativeAndVerticalCoordinates() {
        let above = DisplayArea(id: "above", frame: CGRect(x: 0, y: 900, width: 1920, height: 1080), visibleFrame: CGRect(x: 0, y: 900, width: 1920, height: 1056))
        XCTAssertEqual(DisplayLayout.destination(at: CGPoint(x: -900, y: -50), in: [main, left, above]), left)
        XCTAssertEqual(DisplayLayout.destination(at: CGPoint(x: 100, y: 1200), in: [main, left, above]), above)
        XCTAssertEqual(DisplayLayout.destination(at: CGPoint(x: 800, y: 300), in: [main, left, above]), main)
        XCTAssertEqual(DisplayLayout.destination(at: CGPoint(x: -2000, y: -50), in: [main, left]), left)
        XCTAssertNil(DisplayLayout.destination(at: .zero, in: []))
    }

    func testSavedDisplaySurvivesReorderingDisconnectAndReconnect() throws {
        let project = TodoProject(name: "External", colorIndex: 0, dockEdge: .right, dockPosition: 0.35, displayID: left.id)
        let restored = try JSONDecoder().decode(TodoProject.self, from: JSONEncoder().encode(project))
        XCTAssertEqual(restored, project)
        XCTAssertEqual(DisplayLayout.resolve(restored.displayID, in: [left, main]), left)
        XCTAssertEqual(DisplayLayout.resolve(restored.displayID, in: [main]), main)
        XCTAssertEqual(DisplayLayout.resolve(restored.displayID, in: [main, left]), left)
        XCTAssertEqual(DisplayLayout.resolve(nil, in: [main, left]), main)
        XCTAssertNil(DisplayLayout.resolve(left.id, in: []))
    }

    func testCardsAndDetailsStayOnTheirDisplayForEveryEdge() {
        for display in [main, left] {
            for edge in ScreenEdge.allCases {
                for fraction in [0.0, 0.5, 1.0] {
                    let card = DisplayLayout.cardFrame(edge: edge, position: fraction, in: display.visibleFrame)
                    XCTAssertTrue(display.visibleFrame.contains(card))
                    let size = CGSize(width: 396, height: 590)
                    let detail = CGRect(origin: DisplayLayout.detailOrigin(card: card, edge: edge, size: size, in: display.visibleFrame), size: size)
                    XCTAssertTrue(display.visibleFrame.contains(detail))
                }
                let card = DisplayLayout.cardFrame(edge: edge, position: 0.5, in: display.visibleFrame)
                let attachment = DisplayLayout.attachment(for: card, in: display.visibleFrame)
                XCTAssertEqual(attachment.edge, edge)
                XCTAssertEqual(attachment.position, 0.5, accuracy: 0.00001)
            }
        }
    }

    func testPlacementClampsOutOfRangeAndInvalidFractions() {
        for fraction in [-5.0, 4.0, Double.nan, Double.infinity] {
            XCTAssertTrue(left.visibleFrame.contains(DisplayLayout.cardFrame(edge: .top, position: fraction, in: left.visibleFrame)))
        }
    }
}
