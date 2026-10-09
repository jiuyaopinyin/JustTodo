import Foundation
import CoreGraphics

public struct DisplayArea: Equatable, Sendable {
    public let id: String
    public let frame: CGRect
    public let visibleFrame: CGRect

    public init(id: String, frame: CGRect, visibleFrame: CGRect) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
    }
}

public enum DisplayLayout {
    /// Missing displays fall back without overwriting the saved display identity.
    public static func resolve(_ id: String?, in displays: [DisplayArea]) -> DisplayArea? {
        displays.first(where: { $0.id == id }) ?? displays.first
    }

    public static func destination(at point: CGPoint, in displays: [DisplayArea]) -> DisplayArea? {
        if let containing = displays.first(where: { $0.frame.contains(point) }) { return containing }
        func distance(_ frame: CGRect) -> CGFloat {
            let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
            let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
            return dx * dx + dy * dy
        }
        return displays.min { distance($0.frame) < distance($1.frame) }
    }

    public static func cardSize(for edge: ScreenEdge) -> CGSize {
        edge == .top ? CGSize(width: 50, height: 60) : CGSize(width: 60, height: 50)
    }

    public static func cardFrame(edge: ScreenEdge, position: Double, in frame: CGRect) -> CGRect {
        let size = cardSize(for: edge)
        let fraction = CGFloat(position.isFinite ? min(1, max(0, position)) : 0.5)
        switch edge {
        case .left:
            return CGRect(x: frame.minX, y: frame.maxY - size.height - fraction * max(0, frame.height - size.height), width: size.width, height: size.height)
        case .right:
            return CGRect(x: frame.maxX - size.width, y: frame.maxY - size.height - fraction * max(0, frame.height - size.height), width: size.width, height: size.height)
        case .top:
            return CGRect(x: frame.minX + fraction * max(0, frame.width - size.width), y: frame.maxY - size.height, width: size.width, height: size.height)
        }
    }

    public static func attachment(for card: CGRect, in frame: CGRect) -> (edge: ScreenEdge, position: Double) {
        let distances: [(ScreenEdge, CGFloat)] = [
            (.left, abs(card.minX - frame.minX)),
            (.right, abs(card.maxX - frame.maxX)),
            (.top, abs(card.maxY - frame.maxY))
        ]
        let edge = distances.min { $0.1 < $1.1 }!.0
        let size = cardSize(for: edge)
        let position = edge == .top
            ? (card.midX - size.width / 2 - frame.minX) / max(1, frame.width - size.width)
            : (frame.maxY - card.midY - size.height / 2) / max(1, frame.height - size.height)
        return (edge, Double(min(1, max(0, position))))
    }

    public static func detailOrigin(card: CGRect, edge: ScreenEdge, size: CGSize, in frame: CGRect) -> CGPoint {
        let proposed: CGPoint
        switch edge {
        case .left: proposed = CGPoint(x: card.maxX + 12, y: card.midY - size.height / 2)
        case .right: proposed = CGPoint(x: card.minX - size.width - 12, y: card.midY - size.height / 2)
        case .top: proposed = CGPoint(x: card.midX - size.width / 2, y: card.minY - size.height - 12)
        }
        return CGPoint(x: max(frame.minX + 8, min(proposed.x, frame.maxX - size.width - 8)),
                       y: max(frame.minY + 8, min(proposed.y, frame.maxY - size.height - 8)))
    }
}
