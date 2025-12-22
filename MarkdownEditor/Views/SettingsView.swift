import SwiftUI

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
        .frame(width: 420, height: 260)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

#Preview {
    SettingsView()
}
