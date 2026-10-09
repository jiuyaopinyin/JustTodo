import SwiftUI

struct TaskEditDraft: Identifiable {
    let id: UUID
    let projectID: UUID
    let title: String
}

struct TaskEditor: View {
    @ObservedObject var store: TodoStore
    @State private var text: String
    @FocusState private var focused: Bool
    let cancel: () -> Void
    let save: (String) -> Void

    init(store: TodoStore, initialText: String, cancel: @escaping () -> Void, save: @escaping (String) -> Void) {
        self.store = store
        _text = State(initialValue: initialText)
        self.cancel = cancel
        self.save = save
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(store.t(.editTask)).font(Typography.font(size: 17, weight: .semibold)).textSelection(.enabled)
            TextEditor(text: $text)
                .font(Typography.font(size: 13))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.white.opacity(0.8))
                .overlay(Rectangle().strokeBorder(.primary.opacity(0.12)))
                .focused($focused)
                .accessibilityLabel(store.t(.taskContent))
            HStack {
                Spacer()
                Button(store.t(.cancel), action: cancel).keyboardShortcut(.cancelAction)
                Button(store.t(.save)) { save(text) }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20).frame(width: 360, height: 300)
        .onAppear { focused = true }
        .preferredColorScheme(.light)
        .font(Typography.font(size: 13))
        .environment(\.locale, store.locale)
    }
}
