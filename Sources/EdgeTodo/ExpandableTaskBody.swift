import SwiftUI

private struct FullTextHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct PreviewTextHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct ExpandableTaskBody: View {
    @ObservedObject var store: TodoStore
    let text: String
    let isCompleted: Bool
    @State private var expanded = false
    @State private var fullHeight: CGFloat = 0
    @State private var previewHeight: CGFloat = 0

    private var overflows: Bool { previewHeight > 0 && fullHeight > previewHeight + 0.5 }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(text)
                .font(Typography.font(size: 13))
                .strikethrough(isCompleted)
                .foregroundStyle(Theme.ink.opacity(isCompleted ? 0.4 : 1))
                .lineLimit(expanded ? nil : 5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                // Measure both layouts at the displayed width, including soft wraps.
                // The hidden copies never participate in selection or accessibility.
                .background(alignment: .topLeading) {
                    measuringText(limit: nil)
                        .background(GeometryReader { proxy in
                            Color.clear.preference(key: FullTextHeight.self, value: proxy.size.height)
                        })
                        .hidden().accessibilityHidden(true).allowsHitTesting(false)
                }
                .background(alignment: .topLeading) {
                    measuringText(limit: 5)
                        .background(GeometryReader { proxy in
                            Color.clear.preference(key: PreviewTextHeight.self, value: proxy.size.height)
                        })
                        .hidden().accessibilityHidden(true).allowsHitTesting(false)
                }

            if overflows {
                HStack {
                    Spacer(minLength: 8)
                    Button(store.t(expanded ? .collapse : .expand)) { expanded.toggle() }
                        .font(Typography.font(size: 11)).foregroundStyle(Theme.ink.opacity(0.65))
                        .buttonStyle(.plain)
                        .help(store.t(expanded ? .collapseHint : .expandHint))
                        .accessibilityValue(store.t(expanded ? .expanded : .collapsed))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onPreferenceChange(FullTextHeight.self) { fullHeight = $0 }
        .onPreferenceChange(PreviewTextHeight.self) { previewHeight = $0 }
        .onChange(of: text) { _, _ in expanded = false }
    }

    private func measuringText(limit: Int?) -> some View {
        Text(text)
            .font(Typography.font(size: 13))
            .lineLimit(limit)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.disabled)
    }
}
