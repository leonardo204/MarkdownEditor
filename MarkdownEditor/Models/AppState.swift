import SwiftUI
import Combine

// 앱 전역 상태 관리
// 테마, 설정 등을 관리합니다.

class AppState: ObservableObject {
    // MARK: - 테마 설정
    @Published var editorTheme: EditorTheme = .dark
    @Published var previewTheme: PreviewTheme = .dark

    // MARK: - 미리보기 설정
    @Published var previewMode: PreviewMode = .preview
    @Published var autoReloadPreview: Bool = true

    // MARK: - 에디터 설정
    @Published var showLineNumbers: Bool = true
    @Published var fontSize: CGFloat = 14
    @Published var fontName: String = "SF Mono"

    // MARK: - 초기화
    init() {
        loadSettings()
    }

    // MARK: - 설정 로드
    func loadSettings() {
        let defaults = UserDefaults.standard

        if let rawValue = defaults.string(forKey: "editorTheme"),
           let theme = EditorTheme(rawValue: rawValue) {
            editorTheme = theme
        }

        if let rawValue = defaults.string(forKey: "previewTheme"),
           let theme = PreviewTheme(rawValue: rawValue) {
            previewTheme = theme
        }

        if let rawValue = defaults.string(forKey: "previewMode"),
           let mode = PreviewMode(rawValue: rawValue) {
            previewMode = mode
        }

        autoReloadPreview = defaults.object(forKey: "autoReloadPreview") as? Bool ?? true
        showLineNumbers = defaults.object(forKey: "showLineNumbers") as? Bool ?? true

        let savedFontSize = defaults.float(forKey: "fontSize")
        fontSize = savedFontSize > 0 ? CGFloat(savedFontSize) : 14

        fontName = defaults.string(forKey: "fontName") ?? "SF Mono"
    }

    // MARK: - 설정 저장
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(editorTheme.rawValue, forKey: "editorTheme")
        defaults.set(previewTheme.rawValue, forKey: "previewTheme")
        defaults.set(previewMode.rawValue, forKey: "previewMode")
        defaults.set(autoReloadPreview, forKey: "autoReloadPreview")
        defaults.set(showLineNumbers, forKey: "showLineNumbers")
        defaults.set(Float(fontSize), forKey: "fontSize")
        defaults.set(fontName, forKey: "fontName")
    }
}

// MARK: - 에디터 테마
enum EditorTheme: String, CaseIterable {
    case dark
    case light

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }

    var backgroundColor: NSColor {
        switch self {
        case .dark: return NSColor(red: 0.157, green: 0.173, blue: 0.204, alpha: 1.0)  // #282C34
        case .light: return NSColor(red: 0.980, green: 0.980, blue: 0.980, alpha: 1.0) // #FAFAFA
        }
    }

    var textColor: NSColor {
        switch self {
        case .dark: return NSColor(red: 0.671, green: 0.698, blue: 0.749, alpha: 1.0)  // #ABB2BF
        case .light: return NSColor(red: 0.220, green: 0.227, blue: 0.259, alpha: 1.0) // #383A42
        }
    }

    var cursorColor: NSColor {
        switch self {
        case .dark: return NSColor(red: 0.380, green: 0.612, blue: 0.937, alpha: 1.0)  // #619CD6
        case .light: return NSColor(red: 0.251, green: 0.471, blue: 0.949, alpha: 1.0) // #4078F2
        }
    }

    var selectionColor: NSColor {
        switch self {
        case .dark: return NSColor(red: 0.263, green: 0.298, blue: 0.369, alpha: 1.0)  // #434C5E
        case .light: return NSColor(red: 0.827, green: 0.882, blue: 0.976, alpha: 1.0) // #D3E1F9
        }
    }

    var lineNumberColor: NSColor {
        switch self {
        case .dark: return NSColor(red: 0.361, green: 0.388, blue: 0.443, alpha: 1.0)  // #5C6370
        case .light: return NSColor(red: 0.627, green: 0.631, blue: 0.655, alpha: 1.0) // #A0A1A7
        }
    }
}

// MARK: - 미리보기 테마
enum PreviewTheme: String, CaseIterable {
    case dark
    case light

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }

    var mermaidTheme: String {
        switch self {
        case .dark: return "dark"
        case .light: return "default"
        }
    }
}

// MARK: - 미리보기 모드
enum PreviewMode: String, CaseIterable {
    case preview
    case html

    var displayName: String {
        switch self {
        case .preview: return "Preview"
        case .html: return "HTML"
        }
    }
}
