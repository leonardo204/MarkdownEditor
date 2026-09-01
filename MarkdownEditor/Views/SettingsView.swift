import SwiftUI
import AppKit

// 환경설정 뷰
// 에디터, 미리보기, 일반 설정을 관리합니다.

struct SettingsView: View {
    var body: some View {
        TabView {
            PremiumSettingsView()
                .tabItem {
                    Label("settings.tab.premium", systemImage: "star.fill")
                }

            EditorSettingsView()
                .tabItem {
                    Label("settings.tab.editor", systemImage: "pencil")
                }

            PreviewSettingsView()
                .tabItem {
                    Label("settings.tab.preview", systemImage: "eye")
                }

            GeneralSettingsView()
                .tabItem {
                    Label("settings.tab.general", systemImage: "gear")
                }

            AboutSettingsView()
                .tabItem {
                    Label("settings.tab.about", systemImage: "info.circle")
                }
        }
        .frame(width: 460, height: 400)
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
                Text("settings.theme")
                    .frame(width: 100, alignment: .leading)
                Picker("", selection: $editorTheme) {
                    Text("settings.theme.dark").tag("dark")
                    Text("settings.theme.light").tag("light")
                }
                .labelsHidden()
                .frame(width: 120)
            }

            // 폰트 선택
            HStack {
                Text("settings.font")
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
                Text("settings.font_size")
                    .frame(width: 100, alignment: .leading)
                Slider(value: $fontSize, in: 10...24, step: 1)
                    .frame(width: 140)
                Text(L("settings.unit.pt", Int(fontSize)))
                    .foregroundColor(.secondary)
                    .frame(width: 45, alignment: .trailing)
            }

            // 라인 번호 표시
            HStack {
                Text("settings.line_numbers")
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
    @AppStorage("imageRenderMode") private var imageRenderMode: String = "optimized"
    @AppStorage("imageMaxWidth") private var imageMaxWidth: Double = 680

    // 프리뷰 패널 최대 폭 (메인 윈도우 폭의 약 절반 - 패딩)
    private var maxSliderWidth: Double {
        let docWindow = NSApp.windows.first(where: { window in
            window.isVisible &&
            !window.isSheet &&
            !(window is NSPanel) &&
            window != window.attachedSheet &&
            window.frame.width > 400
        })
        if let window = docWindow {
            return max(200, Double(window.frame.width / 2 - 60))
        }
        return 680
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 테마 선택
            HStack {
                Text("settings.theme")
                    .frame(width: 100, alignment: .leading)
                Picker("", selection: $previewTheme) {
                    Text("settings.theme.dark").tag("dark")
                    Text("settings.theme.light").tag("light")
                }
                .labelsHidden()
                .frame(width: 120)
            }

            // 기본 모드
            HStack {
                Text("settings.default_mode")
                    .frame(width: 100, alignment: .leading)
                Picker("", selection: $previewMode) {
                    Text("settings.mode.preview").tag("preview")
                    Text("settings.mode.html").tag("html")
                }
                .labelsHidden()
                .frame(width: 120)
            }

            // 자동 새로고침
            HStack {
                Text("settings.auto_reload")
                    .frame(width: 100, alignment: .leading)
                Toggle("", isOn: $autoReloadPreview)
                    .labelsHidden()
                Spacer()
            }

            // 이미지 크기
            HStack {
                Text("settings.image_size")
                    .frame(width: 100, alignment: .leading)
                Picker("", selection: $imageRenderMode) {
                    Text("settings.image.optimized").tag("optimized")
                    Text("settings.image.original").tag("original")
                }
                .labelsHidden()
                .frame(width: 120)
            }

            // 이미지 최대 너비 (Optimized 모드일 때)
            if imageRenderMode == "optimized" {
                HStack {
                    Text("settings.max_width")
                        .frame(width: 100, alignment: .leading)
                    Slider(value: $imageMaxWidth, in: 200...maxSliderWidth)
                        .frame(width: 140)
                    Text(L("settings.unit.px", Int(imageMaxWidth)))
                        .foregroundColor(.secondary)
                        .frame(width: 55, alignment: .trailing)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if imageMaxWidth > maxSliderWidth {
                imageMaxWidth = maxSliderWidth
            }
        }
    }
}

// MARK: - 일반 설정
struct GeneralSettingsView: View {
    @AppStorage(AppLanguage.storageKey) private var appLanguage: String = AppLanguage.system.rawValue
    @AppStorage("syncScrolling") private var syncScrolling: Bool = true
    @AppStorage("openFilesInNewTab") private var openFilesInNewTab: Bool = true
    @AppStorage("showPreviewPane") private var showPreviewPane: Bool = true
    @AppStorage("rememberWindowSize") private var rememberWindowSize: Bool = false
    @State private var showingShortcuts = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 표시 언어
            HStack(alignment: .firstTextBaseline) {
                Text("settings.language")
                    .frame(width: 100, alignment: .leading)
                Picker("", selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
                .onChange(of: appLanguage) { newValue in
                    (AppLanguage(rawValue: newValue) ?? .system).apply()
                }
                Text("settings.language.restart_note")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Divider()
                .padding(.vertical, 4)

            // 탭 설정
            HStack {
                Text("settings.open_files_in")
                    .frame(width: 100, alignment: .leading)
                Picker("", selection: $openFilesInNewTab) {
                    Text("settings.open.new_tab").tag(true)
                    Text("settings.open.new_window").tag(false)
                }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()
                .labelsHidden()
            }

            Divider()
                .padding(.vertical, 4)

            // 스크롤 동기화
            HStack {
                Text("settings.scroll_sync")
                    .frame(width: 100, alignment: .leading)
                Toggle("", isOn: $syncScrolling)
                    .labelsHidden()
                Text("settings.scroll_sync.desc")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Divider()
                .padding(.vertical, 4)

            // 미리보기 패널 표시
            HStack {
                Text("settings.preview_pane")
                    .frame(width: 100, alignment: .leading)
                Toggle("", isOn: $showPreviewPane)
                    .labelsHidden()
                Text("settings.preview_pane.desc")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Divider()
                .padding(.vertical, 4)

            // 창 크기 기억
            HStack {
                Text("settings.window_size")
                    .frame(width: 100, alignment: .leading)
                Toggle("", isOn: $rememberWindowSize)
                    .labelsHidden()
                Text("settings.window_size.desc")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Divider()
                .padding(.vertical, 4)

            // 단축키 안내
            HStack {
                Text("settings.shortcuts")
                    .frame(width: 100, alignment: .leading)
                Button(action: { showingShortcuts = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 11))
                        Text("settings.shortcuts.button")
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

// MARK: - Premium 설정
struct PremiumSettingsView: View {
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var showConfetti = false

    var body: some View {
        VStack(spacing: 16) {
            if storeManager.isPremium {
                // 구매 완료 상태
                VStack(spacing: 14) {
                    ZStack {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(showConfetti ? 1.0 : 0.5)
                            .opacity(showConfetti ? 1.0 : 0.0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showConfetti)

                        // 축하 이펙트
                        ForEach(0..<6, id: \.self) { i in
                            Image(systemName: ["star.fill", "sparkle", "heart.fill", "star.fill", "sparkle", "heart.fill"][i])
                                .font(.system(size: 10))
                                .foregroundColor([.yellow, .orange, .pink, .purple, .cyan, .mint][i])
                                .offset(
                                    x: showConfetti ? CGFloat([-30, 28, -20, 25, -32, 22][i]) : 0,
                                    y: showConfetti ? CGFloat([-25, -20, 15, 18, 5, -28][i]) : 0
                                )
                                .opacity(showConfetti ? 0.8 : 0.0)
                                .scaleEffect(showConfetti ? 1.0 : 0.0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.5).delay(Double(i) * 0.05), value: showConfetti)
                        }
                    }
                    .frame(height: 60)

                    Text("premium.activated.title")
                        .font(.headline)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("premium.activated.desc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .onAppear { showConfetti = true }
            } else {
                // 미구매 상태
                VStack(spacing: 12) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)

                    Text("premium.title")
                        .font(.headline)

                    Text("premium.desc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)

                    if let product = storeManager.products.first {
                        Button(action: {
                            Task { await storeManager.purchase(product) }
                        }) {
                            HStack {
                                if storeManager.purchaseInProgress {
                                    ProgressView()
                                        .controlSize(.small)
                                        .padding(.trailing, 4)
                                }
                                Text(L("premium.purchase", product.displayPrice))
                            }
                            .frame(minWidth: 160)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(storeManager.purchaseInProgress)
                    } else if storeManager.isLoadingProducts {
                        ProgressView()
                            .controlSize(.small)
                        Text("premium.loading")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text(storeManager.errorMessage ?? L("premium.not_found"))
                            .font(.caption2)
                            .foregroundColor(.red)

                        Button("premium.retry") {
                            Task { await storeManager.loadProducts() }
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }

                    Button("premium.restore") {
                        Task { await storeManager.restorePurchases() }
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }

                if storeManager.products.first != nil, let error = storeManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            Text(L("about.version", appVersion, buildNumber))
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()
                .frame(width: 200)

            // 저작 정보
            VStack(spacing: 4) {
                Text(L("about.rights", String(Calendar.current.component(.year, from: Date()))))
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
                Text("shortcuts.title")
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
                    ShortcutSection(title: "shortcuts.section.file", icon: "doc", shortcuts: [
                        ShortcutItem(keys: "⌘ N", description: "shortcuts.new_document"),
                        ShortcutItem(keys: "⌘ T", description: "shortcuts.new_tab"),
                        ShortcutItem(keys: "⇧⌘ N", description: "shortcuts.new_window"),
                        ShortcutItem(keys: "⌘ O", description: "shortcuts.open"),
                        ShortcutItem(keys: "⌘ W", description: "shortcuts.close_tab"),
                        ShortcutItem(keys: "⌘ S", description: "shortcuts.save"),
                        ShortcutItem(keys: "⇧⌘ S", description: "shortcuts.save_as")
                    ])

                    // 탭 관련
                    ShortcutSection(title: "shortcuts.section.tabs", icon: "rectangle.stack", shortcuts: [
                        ShortcutItem(keys: "⇧⌘ ]", description: "shortcuts.next_tab"),
                        ShortcutItem(keys: "⇧⌘ [", description: "shortcuts.previous_tab"),
                        ShortcutItem(keys: "⌘ 1-9", description: "shortcuts.go_to_tab")
                    ])

                    // 편집 관련
                    ShortcutSection(title: "shortcuts.section.edit", icon: "pencil", shortcuts: [
                        ShortcutItem(keys: "⌘ Z", description: "shortcuts.undo"),
                        ShortcutItem(keys: "⇧⌘ Z", description: "shortcuts.redo"),
                        ShortcutItem(keys: "⌘ X", description: "shortcuts.cut"),
                        ShortcutItem(keys: "⌘ C", description: "shortcuts.copy"),
                        ShortcutItem(keys: "⌘ V", description: "shortcuts.paste"),
                        ShortcutItem(keys: "⌘ A", description: "shortcuts.select_all")
                    ])

                    // 서식 관련
                    ShortcutSection(title: "shortcuts.section.format", icon: "textformat", shortcuts: [
                        ShortcutItem(keys: "⌘ B", description: "shortcuts.bold"),
                        ShortcutItem(keys: "⌘ I", description: "shortcuts.italic"),
                        ShortcutItem(keys: "⌘ U", description: "shortcuts.underline"),
                        ShortcutItem(keys: "⌘ K", description: "shortcuts.insert_link"),
                        ShortcutItem(keys: "⌃ O", description: "shortcuts.insert_image")
                    ])

                    // 보기 관련
                    ShortcutSection(title: "shortcuts.section.view", icon: "eye", shortcuts: [
                        ShortcutItem(keys: "⇧⌘ O", description: "shortcuts.toggle_outline"),
                        ShortcutItem(keys: "⌘ ,", description: "shortcuts.settings")
                    ])
                }
                .padding(24)
            }

            Divider()

            // 푸터
            HStack {
                Spacer()
                Button("button.close") {
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
