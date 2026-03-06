import Foundation

/// Public accessor for Bundle.module URL (for Quick Look extension resource loading)
public let resourceBundleURL: URL = Bundle.module.bundleURL

public enum PreviewTheme: String, CaseIterable, Sendable {
    case dark
    case light

    public var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }

    public var mermaidTheme: String {
        switch self {
        case .dark: return "dark"
        case .light: return "default"
        }
    }
}
