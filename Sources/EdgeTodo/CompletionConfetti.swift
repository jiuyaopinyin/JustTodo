import SwiftUI

struct CompletionConfetti: View {
    static let duration: TimeInterval = 2.2
    let origin: CGPoint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date.now

    private let colors: [Color] = [.pink, .orange, .yellow, .mint, .cyan, .purple]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startedAt)
            Canvas { context, _ in
                for index in 0..<(reduceMotion ? 24 : 72) {
                    let age = elapsed - sample(index, 1) * 0.16
                    guard age >= 0, age < Self.duration else { continue }
                    let x: CGFloat
                    let y: CGFloat
                    let angle: Double
                    let flip: Double
                    if reduceMotion {
                        // Keep the reduced-motion celebration local to the clicked button.
                        let direction = sample(index, 2) * .pi * 2
                        let radius = 12 + sample(index, 3) * 36
                        x = origin.x + cos(direction) * radius
                        y = origin.y + sin(direction) * radius
                        angle = sample(index, 4) * .pi
                        flip = 1
                    } else {
                        // Burst from the button, mostly up and into the card, then fall.
                        let direction = -.pi * 0.95 + sample(index, 2) * .pi * 1.1
                        let speed = 110 + sample(index, 3) * 180
                        let travel = (1 - exp(-1.4 * age)) / 1.4
                        x = origin.x + cos(direction) * speed * travel
                        y = origin.y + sin(direction) * speed * travel + 90 * age * age
                        angle = sample(index, 6) * .pi * 2 + age * (sample(index, 7) - 0.5) * 10
                        flip = 0.25 + 0.75 * abs(cos(age * 7 + sample(index, 8) * .pi))
                    }
                    let width = (4 + sample(index, 9) * 4) * flip
                    let height = 5 + sample(index, 10) * 7
                    var particle = context
                    particle.opacity = min(1, max(0, (Self.duration - age) / 0.65))
                    particle.translateBy(x: x, y: y)
                    particle.rotate(by: .radians(angle))
                    let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
                    particle.fill(Path(rect), with: .color(colors[index % colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // Stable particle parameters prevent jumps when the parent view updates.
    private func sample(_ index: Int, _ channel: Int) -> Double {
        let value = sin(Double(index * 127 + channel * 311)) * 43_758.5453
        return value - floor(value)
    }
}
