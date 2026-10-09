import AppKit
import CoreText
import SwiftUI

enum Typography {
    // Register only for this process; no installation into the user's font library.
    static func registerDisplayFont() {
        let resources = Bundle.main.url(forResource: "JustTodo_JustTodo", withExtension: "bundle")
            .flatMap { Bundle(url: $0) } ?? Bundle.module
        guard let url = resources.url(forResource: "Orbitron-SemiBold", withExtension: "ttf", subdirectory: "Fonts") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    static func dockNumber(size: CGFloat) -> Font {
        .custom("Orbitron-SemiBold", fixedSize: size)
    }

    // SF Mono for Latin text and numerals; macOS supplies CJK fallback glyphs.
    static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func native(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        .monospacedSystemFont(ofSize: size, weight: weight)
    }

    @MainActor static func style(_ alert: NSAlert) {
        alert.layout()
        if let content = alert.window.contentView { styleSubviews(content) }
    }

    @MainActor private static func styleSubviews(_ view: NSView) {
        if let field = view as? NSTextField {
            let old = field.font ?? .systemFont(ofSize: 13)
            let bold = NSFontManager.shared.traits(of: old).contains(.boldFontMask)
            field.font = native(size: old.pointSize, weight: bold ? .semibold : .regular)
        } else if let button = view as? NSButton {
            button.font = native(size: button.font?.pointSize ?? 13)
        }
        view.subviews.forEach(styleSubviews)
    }
}
