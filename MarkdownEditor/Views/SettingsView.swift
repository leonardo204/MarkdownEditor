import SwiftUI
import AppKit

// 환경설정 뷰
// 에디터, 미리보기, 일반 설정을 관리합니다.

struct SettingsView: View {
    var body: some View {
        TabView {
            EditorSettingsView()
                .tabItem {
                    Label("Editor", systemImage: "pencil")
                }

            PreviewSettingsView()
                .tabItem {
                    Label("Preview", systemImage: "eye")
                }

            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 420, height: 300)
    }
}

// MARK: - 에디터 설정
struct EditorSettingsView: View {
    @AppStorage("editorTheme") private var editorTheme: String = "dark"
    @AppStorage("fontSize") private var fontSize: Double = 14
    @AppStorage("fontName") private var fontName: String = "SF Mono"
    @AppStorage("showLineNumbers") private var showLineNumbers: Bool = true

    // 사용 가능한 폰트 목록
    private let availableFonts = [
        "SF Mono",
        "Menlo",
        "Monaco",
        "Courier New",
        "Fira Code",
        "JetBrains Mono",
        "Source Code Pro"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 테마 선택
            HStack {
                Text("Theme")
                    .frame(width: 100, alignment: .leading)
                Picker("", selection: $editorTheme) {
                    Text("Dark").tag("dark")
                    Text("Light").tag("light")
                }
                .labelsHidden()
                .frame(width: 120)
            }

            // 폰트 선택
            HStack {
                Text("Font")
                    .frame(width: 100, alignment: .leading)
                Picker("", selection: $fontName) {
                    ForEach(availableFonts, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
            }

            // 폰트 크기
            HStack {
                Text("Font Size")
                    .frame(width: 100, alignment: .leading)
                Slider(value: $fontSize, in: 10...24, step: 1)
                    .frame(width: 140)
                Text("\(Int(fontSize)) pt")
                    .foregroundColor(.secondary)
                    .frame(width: 45, alignment: .trailing)
            }

            // 라인 번호 표시
            HStack {
                Text("Line Numbers")
                    .frame(width: 100, alignment: .leading)
                Toggle("", isOn: $showLineNumbers)
                    .labelsHidden()
                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - 미리보기 설정
struct PreviewSettingsView: View {
    @AppStorage("previewTheme") private var previewTheme: String = "dark"
    @AppStorage("previewMode") private var previewMode: String = "preview"
    @AppStorage("autoReloadPreview") private var autoReloadPreview: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 테마 선택
            HStack {
                Text("Theme")
                    .frame(width: 100, alignment: .leading)
                Picker("", selection: $previewTheme) {
                    Text("Dark").tag("dark")
                    Text("Light").tag("light")
                }
                .labelsHidden()
                .frame(width: 120)
            }

            // 기본 모드
            HStack {
                Text("Default Mode")
                    .frame(width: 100, alignment: .leading)
                Picker("", selection: $previewMode) {
                    Text("Preview").tag("preview")
                    Text("HTML Source").tag("html")
                }
                .labelsHidden()
                .frame(width: 120)
            }

            // 자동 새로고침
            HStack {
                Text("Auto Reload")
                    .frame(width: 100, alignment: .leading)
                Toggle("", isOn: $autoReloadPreview)
                    .labelsHidden()
                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - 일반 설정
struct GeneralSettingsView: View {
    @AppStorage("syncScrolling") private var syncScrolling: Bool = true
    @AppStorage("autosave") private var autosave: Bool = true
    @AppStorage("autosaveInterval") private var autosaveInterval: Double = 30
    @AppStorage("openFilesInNewTab") private var openFilesInNewTab: Bool = true
    @State private var showingShortcuts = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 탭 설정
            HStack {
                Text("Open Files In")
                    .frame(width: 100, alignment: .leading)
                Picker("", selection: $openFilesInNewTab) {
                    Text("New Tab").tag(true)
                    Text("New Window").tag(false)
                }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()
                .labelsHidden()
            }

            Divider()
                .padding(.vertical, 4)

            // 스크롤 동기화
            HStack {
                Text("Scroll Sync")
                    .frame(width: 100, alignment: .leading)
                Toggle("", isOn: $syncScrolling)
                    .labelsHidden()
                Text("Sync editor and preview")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // 자동 저장
            HStack {
                Text("Auto Save")
                    .frame(width: 100, alignment: .leading)
                Toggle("", isOn: $autosave)
                    .labelsHidden()
                Spacer()
            }

            // 자동 저장 간격
            if autosave {
                HStack {
                    Text("Save Interval")
                        .frame(width: 100, alignment: .leading)
                    Slider(value: $autosaveInterval, in: 10...120, step: 10)
                        .frame(width: 140)
                    Text("\(Int(autosaveInterval)) sec")
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
            }

            Divider()
                .padding(.vertical, 4)

            // 단축키 안내
            HStack {
                Text("Shortcuts")
                    .frame(width: 100, alignment: .leading)
                Button(action: { showingShortcuts = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 11))
                        Text("View Keyboard Shortcuts")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showingShortcuts) {
            KeyboardShortcutsView()
        }
    }
}

// MARK: - About 설정
struct AboutSettingsView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 16) {
            // 앱 아이콘
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            // 앱 이름
            Text("Markdown Editor")
                .font(.title2)
                .fontWeight(.semibold)

            // 버전 정보
            Text("Version \(appVersion) (\(buildNumber))")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()
                .frame(width: 200)

            // 저작 정보
            VStack(spacing: 4) {
                Text("© 2025 All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Link("zerolive7@gmail.com", destination: URL(string: "mailto:zerolive7@gmail.com")!)
                    .font(.caption)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 단축키 안내 모달
struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            // 단축키 목록
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 파일 관련
                    ShortcutSection(title: "File", icon: "doc", shortcuts: [
                        ShortcutItem(keys: "⌘ N", description: "New Document"),
                        ShortcutItem(keys: "⌘ T", description: "New Tab"),
                        ShortcutItem(keys: "⇧⌘ N", description: "New Window"),
                        ShortcutItem(keys: "⌘ O", description: "Open..."),
                        ShortcutItem(keys: "⌘ W", description: "Close Tab"),
                        ShortcutItem(keys: "⌘ S", description: "Save"),
                        ShortcutItem(keys: "⇧⌘ S", description: "Save As...")
                    ])

                    // 탭 관련
                    ShortcutSection(title: "Tabs", icon: "rectangle.stack", shortcuts: [
                        ShortcutItem(keys: "⇧⌘ ]", description: "Next Tab"),
                        ShortcutItem(keys: "⇧⌘ [", description: "Previous Tab"),
                        ShortcutItem(keys: "⌘ 1-9", description: "Go to Tab 1-9")
                    ])

                    // 편집 관련
                    ShortcutSection(title: "Edit", icon: "pencil", shortcuts: [
                        ShortcutItem(keys: "⌘ Z", description: "Undo"),
                        ShortcutItem(keys: "⇧⌘ Z", description: "Redo"),
                        ShortcutItem(keys: "⌘ X", description: "Cut"),
                        ShortcutItem(keys: "⌘ C", description: "Copy"),
                        ShortcutItem(keys: "⌘ V", description: "Paste"),
                        ShortcutItem(keys: "⌘ A", description: "Select All")
                    ])

                    // 서식 관련
                    ShortcutSection(title: "Format", icon: "textformat", shortcuts: [
                        ShortcutItem(keys: "⌘ B", description: "Bold"),
                        ShortcutItem(keys: "⌘ I", description: "Italic"),
                        ShortcutItem(keys: "⌘ U", description: "Underline"),
                        ShortcutItem(keys: "⌘ K", description: "Insert Link")
                    ])

                    // 보기 관련
                    ShortcutSection(title: "View", icon: "eye", shortcuts: [
                        ShortcutItem(keys: "⌘ ,", description: "Settings")
                    ])
                }
                .padding(24)
            }

            Divider()

            // 푸터
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 400, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - 단축키 섹션
struct ShortcutSection: View {
    let title: String
    let icon: String
    let shortcuts: [ShortcutItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 섹션 타이틀
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
            }

            // 단축키 목록
            VStack(spacing: 8) {
                ForEach(shortcuts) { shortcut in
                    ShortcutRow(shortcut: shortcut)
                }
            }
            .padding(.leading, 28)
        }
    }
}

// MARK: - 단축키 아이템
struct ShortcutItem: Identifiable {
    let id = UUID()
    let keys: String
    let description: String
}

// MARK: - 단축키 행
struct ShortcutRow: View {
    let shortcut: ShortcutItem

    var body: some View {
        HStack {
            Text(shortcut.description)
                .font(.system(size: 12))
                .foregroundColor(.primary)

            Spacer()

            // 키 배지들
            HStack(spacing: 4) {
                ForEach(shortcut.keys.split(separator: " ").map(String.init), id: \.self) { key in
                    KeyBadge(key: key)
                }
            }
        }
    }
}

// MARK: - 키 배지
struct KeyBadge: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(.primary.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
    }
}

#Preview {
    SettingsView()
}

#Preview("Keyboard Shortcuts") {
    KeyboardShortcutsView()
}
