import SwiftUI
import Combine
import AppKit

// 앱 전역 상태 관리
// 테마, 설정 등을 관리합니다.

class AppState: ObservableObject {
    // MARK: - 테마 설정
    @Published var editorTheme: EditorTheme = .dark
    @Published var previewTheme: PreviewTheme = .dark

    // MARK: - 미리보기 설정
    @Published var autoReloadPreview: Bool = true

    // MARK: - 에디터 설정
    @Published var showLineNumbers: Bool = true
    @Published var fontSize: CGFloat = 14
    @Published var fontName: String = "SF Mono"

    // MARK: - 탭 설정
    @Published var openFilesInNewTab: Bool = true  // true: 새 탭, false: 새 윈도우

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

        autoReloadPreview = defaults.object(forKey: "autoReloadPreview") as? Bool ?? true
        showLineNumbers = defaults.object(forKey: "showLineNumbers") as? Bool ?? true

        let savedFontSize = defaults.float(forKey: "fontSize")
        fontSize = savedFontSize > 0 ? CGFloat(savedFontSize) : 14

        fontName = defaults.string(forKey: "fontName") ?? "SF Mono"

        // 탭 설정 로드 (기본값: 새 탭에서 열기)
        openFilesInNewTab = defaults.object(forKey: "openFilesInNewTab") as? Bool ?? true
    }

    // MARK: - 설정 저장
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(editorTheme.rawValue, forKey: "editorTheme")
        defaults.set(previewTheme.rawValue, forKey: "previewTheme")
        defaults.set(autoReloadPreview, forKey: "autoReloadPreview")
        defaults.set(showLineNumbers, forKey: "showLineNumbers")
        defaults.set(Float(fontSize), forKey: "fontSize")
        defaults.set(fontName, forKey: "fontName")
        defaults.set(openFilesInNewTab, forKey: "openFilesInNewTab")
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

    // MARK: - 기본 색상
    var backgroundColor: NSColor {
        switch self {
        case .dark: return NSColor(red: 0.118, green: 0.125, blue: 0.157, alpha: 1.0)  // #1E2028 - 더 진한 다크
        case .light: return NSColor(red: 0.988, green: 0.988, blue: 0.992, alpha: 1.0) // #FCFCFD
        }
    }

    var textColor: NSColor {
        switch self {
        case .dark: return NSColor(red: 0.847, green: 0.871, blue: 0.914, alpha: 1.0)  // #D8DEE9 - 더 밝은 텍스트
        case .light: return NSColor(red: 0.180, green: 0.204, blue: 0.251, alpha: 1.0) // #2E3440
        }
    }

    var cursorColor: NSColor {
        switch self {
        case .dark: return NSColor(red: 0.533, green: 0.753, blue: 0.984, alpha: 1.0)  // #88C0FB
        case .light: return NSColor(red: 0.302, green: 0.537, blue: 0.890, alpha: 1.0) // #4D89E3
        }
    }

    var selectionColor: NSColor {
        switch self {
        case .dark: return NSColor(red: 0.263, green: 0.298, blue: 0.369, alpha: 0.6)  // #434C5E with alpha
        case .light: return NSColor(red: 0.737, green: 0.839, blue: 0.976, alpha: 0.5) // #BCD6F9 with alpha
        }
    }

    // MARK: - 라인 번호 영역 (Gutter)
    var lineNumberColor: NSColor {
        switch self {
        case .dark: return NSColor(red: 0.431, green: 0.459, blue: 0.525, alpha: 1.0)  // #6E7586
        case .light: return NSColor(red: 0.553, green: 0.576, blue: 0.616, alpha: 1.0) // #8D939D
        }
    }

    var gutterBackgroundColor: NSColor {
        switch self {
        case .dark: return NSColor(red: 0.098, green: 0.106, blue: 0.133, alpha: 1.0)  // #191B22 - 약간 더 어둡게
        case .light: return NSColor(red: 0.957, green: 0.961, blue: 0.969, alpha: 1.0) // #F4F5F7
        }
    }

    var gutterBorderColor: NSColor {
        switch self {
        case .dark: return NSColor(red: 0.200, green: 0.216, blue: 0.263, alpha: 1.0)  // #333743
        case .light: return NSColor(red: 0.875, green: 0.886, blue: 0.906, alpha: 1.0) // #DFE2E7
        }
    }

    // MARK: - 구문 강조 색상
    var syntaxHeadingColor: NSColor {
        switch self {
        case .dark: return NSColor(red: 0.537, green: 0.706, blue: 0.980, alpha: 1.0)  // #89B4FA - 파랑
        case .light: return NSColor(red: 0.118, green: 0.443, blue: 0.812, alpha: 1.0) // #1E71CF
        }
    }

    var syntaxBoldColor: NSColor {
        switch self {
        case .dark: return NSColor(red: 0.976, green: 0.659, blue: 0.455, alpha: 1.0)  // #F9A874 - 오렌지
        case .light: return NSColor(red: 0.804, green: 0.400, blue: 0.000, alpha: 1.0) // #CD6600
        }
    }

    var syntaxItalicColor: NSColor {
        switch self {
        case .dark: return NSColor(red: 0.796, green: 0.616, blue: 0.882, alpha: 1.0)  // #CB9DE1 - 보라
        case .light: return NSColor(red: 0.635, green: 0.286, blue: 0.643, alpha: 1.0) // #A249A4
        }
    }

    var syntaxCodeColor: NSColor {
        switch self {
        case .dark: return NSColor(red: 0.651, green: 0.890, blue: 0.631, alpha: 1.0)  // #A6E3A1 - 초록
        case .light: return NSColor(red: 0.251, green: 0.627, blue: 0.345, alpha: 1.0) // #40A058
        }
    }

    var syntaxLinkColor: NSColor {
        switch self {
        case .dark: return NSColor(red: 0.529, green: 0.859, blue: 0.922, alpha: 1.0)  // #87DBEB - 시안
        case .light: return NSColor(red: 0.000, green: 0.529, blue: 0.667, alpha: 1.0) // #0087AA
        }
    }

    var syntaxQuoteColor: NSColor {
        switch self {
        case .dark: return NSColor(red: 0.545, green: 0.580, blue: 0.659, alpha: 1.0)  // #8B94A8
        case .light: return NSColor(red: 0.486, green: 0.510, blue: 0.576, alpha: 1.0) // #7C8293
        }
    }

    var syntaxListColor: NSColor {
        switch self {
        case .dark: return NSColor(red: 0.949, green: 0.549, blue: 0.584, alpha: 1.0)  // #F28C95 - 빨강
        case .light: return NSColor(red: 0.851, green: 0.318, blue: 0.275, alpha: 1.0) // #D95146
        }
    }

    var syntaxHrColor: NSColor {
        switch self {
        case .dark: return NSColor(red: 0.451, green: 0.475, blue: 0.545, alpha: 1.0)  // #73798B
        case .light: return NSColor(red: 0.596, green: 0.616, blue: 0.663, alpha: 1.0) // #989DA9
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

