import Foundation

// MARK: - 지역화 문자열 조회 헬퍼
//
// AppKit 코드(메뉴·알림창·패널)에서 쓴다.
// SwiftUI의 Text/Button/Label 등은 LocalizedStringKey를 통해 Localizable.strings를
// 자동으로 조회하므로 이 헬퍼 없이 키를 그대로 넘기면 된다.

/// 키에 해당하는 현재 언어 문자열을 돌려준다.
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// 서식 지정자(%@, %d)가 있는 문자열을 값과 함께 조립한다.
func L(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), arguments: arguments)
}

// MARK: - 앱 표시 언어

/// 설정 > General에서 고를 수 있는 표시 언어.
///
/// 선택 값은 `AppleLanguages`에 기록한다. 이 키는 앱이 켜질 때 번들이 한 번 읽으므로
/// 바꾼 언어는 앱을 다시 켠 뒤에 반영된다(설정 화면에 그 안내를 함께 표시한다).
enum AppLanguage: String, CaseIterable, Identifiable {
    /// 시스템 언어 설정을 그대로 따른다.
    case system
    case korean = "ko"
    case english = "en"
    case japanese = "ja"
    case chineseSimplified = "zh-Hans"

    var id: String { rawValue }

    /// 설정에 저장하는 UserDefaults 키
    static let storageKey = "appLanguage"

    /// 목록에 표시할 이름. 각 언어는 그 언어 자체 표기를 쓴다.
    var displayName: String {
        switch self {
        case .system: return L("settings.language.system")
        case .korean: return "한국어"
        case .english: return "English"
        case .japanese: return "日本語"
        case .chineseSimplified: return "简体中文"
        }
    }

    /// 저장된 설정을 읽는다. 값이 없거나 알 수 없는 값이면 시스템 설정을 따른다.
    static var current: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? ""
        return AppLanguage(rawValue: raw) ?? .system
    }

    /// 선택한 언어를 저장하고 `AppleLanguages`에 반영한다.
    func apply() {
        let defaults = UserDefaults.standard
        defaults.set(rawValue, forKey: AppLanguage.storageKey)

        switch self {
        case .system:
            defaults.removeObject(forKey: "AppleLanguages")
        default:
            defaults.set([rawValue], forKey: "AppleLanguages")
        }
    }
}
