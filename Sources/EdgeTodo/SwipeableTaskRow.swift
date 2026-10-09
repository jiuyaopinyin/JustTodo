import AppKit
import SwiftUI

struct SwipeableTaskRow<Content: View>: View {
    let id: UUID
    @Binding var revealedID: UUID?
    let editTitle: String
    let deleteTitle: String
    let showActionsTitle: String
    let hideActionsTitle: String
    let background: Color
    let edit: () -> Void
    let delete: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var gestureOffset: CGFloat?
    @State private var startingOffset: CGFloat = 0
    private let actionWidth: CGFloat = 112

    private var offset: CGFloat { gestureOffset ?? (revealedID == id ? -actionWidth : 0) }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                Button { close(); edit() } label: {
                    Text(editTitle).frame(width: actionWidth / 2, height: 36)
                        .background(Theme.ink.opacity(0.07))
                }
                Button(role: .destructive) { close(); delete() } label: {
                    Text(deleteTitle).foregroundStyle(.red)
                        .frame(width: actionWidth / 2, height: 36)
                        .background(Color.red.opacity(0.08))
                }
            }
            .font(Typography.font(size: 11)).buttonStyle(.plain)
            .opacity(offset < 0 ? 1 : 0)
            .allowsHitTesting(revealedID == id)
            .accessibilityHidden(revealedID != id)

            content()
                .background { Color.white.overlay(background) }
                .offset(x: offset)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text(revealedID == id ? hideActionsTitle : showActionsTitle)) {
            withAnimation(.easeOut(duration: 0.18)) {
                revealedID = revealedID == id ? nil : id
                gestureOffset = nil
            }
        }
        .background(HorizontalSwipeCapture(
            began: { startingOffset = revealedID == id ? -actionWidth : 0 },
            changed: { delta in gestureOffset = max(-actionWidth, min(0, startingOffset + delta)) },
            ended: { cancelled in
                let shouldOpen = cancelled ? startingOffset < 0 : offset < -actionWidth / 3
                withAnimation(.easeOut(duration: 0.18)) {
                    revealedID = shouldOpen ? id : nil
                    gestureOffset = nil
                }
            }
        ))
        .onChange(of: revealedID) { _, newValue in
            if newValue != id { gestureOffset = nil }
        }
    }

    private func close() {
        revealedID = nil
        gestureOffset = nil
    }
}

// Trackpad swipes arrive as scroll-wheel events on macOS. Observing only horizontal
// gestures keeps vertical scrolling and native text selection/copying available.
private struct HorizontalSwipeCapture: NSViewRepresentable {
    let began: () -> Void
    let changed: (CGFloat) -> Void
    let ended: (Bool) -> Void

    func makeNSView(context: Context) -> SwipeCaptureView { SwipeCaptureView() }
    func updateNSView(_ view: SwipeCaptureView, context: Context) {
        view.began = began
        view.changed = changed
        view.ended = ended
    }
    static func dismantleNSView(_ view: SwipeCaptureView, coordinator: ()) { view.stopMonitoring() }

    final class SwipeCaptureView: NSView {
        var began: () -> Void = {}
        var changed: (CGFloat) -> Void = { _ in }
        var ended: (Bool) -> Void = { _ in }
        private var monitor: Any?
        private var tracking = false
        private var suppressMomentum = false
        private var translation: CGFloat = 0

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                let handled = MainActor.assumeIsolated {
                    guard let self else { return false }
                    return self.handle(event) == nil
                }
                return handled ? nil : event
            }
        }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            tracking = false
            suppressMomentum = false
            translation = 0
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard event.window === window else { return event }
            let isInside = bounds.intersection(visibleRect).contains(convert(event.locationInWindow, from: nil))
            guard tracking || isInside else { return event }
            if !event.momentumPhase.isEmpty { return suppressMomentum ? nil : event }
            if event.phase.contains(.began) { suppressMomentum = false }
            if tracking && (event.phase.contains(.ended) || event.phase.contains(.cancelled)) {
                tracking = false
                ended(event.phase.contains(.cancelled))
                return nil
            }
            let dx = event.scrollingDeltaX
            if !tracking {
                guard abs(dx) > 0.5, abs(dx) > abs(event.scrollingDeltaY) * 1.2 else { return event }
                tracking = true
                suppressMomentum = true
                translation = 0
                began()
            }
            translation += dx
            if event.phase.isEmpty {
                // Mouse wheels and accessibility scroll commands have no gesture
                // phases: treat their horizontal direction as a reveal/close action.
                changed(dx > 0 ? 1_000 : -1_000)
                tracking = false
                ended(false)
            } else {
                changed(translation)
            }
            return nil
        }
    }
}
