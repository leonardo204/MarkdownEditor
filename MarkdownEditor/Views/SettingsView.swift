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
        }
        .frame(width: 450, height: 300)
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
        Form {
            Section {
                // 테마 선택
                Picker("Theme", selection: $editorTheme) {
                    Text("Dark").tag("dark")
                    Text("Light").tag("light")
                }

                // 폰트 선택
                Picker("Font", selection: $fontName) {
                    ForEach(availableFonts, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }

                // 폰트 크기
                HStack {
                    Text("Font Size")
                    Spacer()
                    Slider(value: $fontSize, in: 10...24, step: 1)
                        .frame(width: 150)
                    Text("\(Int(fontSize))")
                        .frame(width: 30)
                }

                // 라인 번호 표시
                Toggle("Show line numbers", isOn: $showLineNumbers)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - 미리보기 설정
struct PreviewSettingsView: View {
    @AppStorage("previewTheme") private var previewTheme: String = "dark"
    @AppStorage("previewMode") private var previewMode: String = "preview"
    @AppStorage("autoReloadPreview") private var autoReloadPreview: Bool = true

    var body: some View {
        Form {
            Section {
                // 테마 선택
                Picker("Theme", selection: $previewTheme) {
                    Text("Dark").tag("dark")
                    Text("Light").tag("light")
                }

                // 기본 모드
                Picker("Default mode", selection: $previewMode) {
                    Text("Preview").tag("preview")
                    Text("HTML Source").tag("html")
                }

                // 자동 새로고침
                Toggle("Auto reload on change", isOn: $autoReloadPreview)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - 일반 설정
struct GeneralSettingsView: View {
    @AppStorage("syncScrolling") private var syncScrolling: Bool = true
    @AppStorage("autosave") private var autosave: Bool = true
    @AppStorage("autosaveInterval") private var autosaveInterval: Double = 30

    var body: some View {
        Form {
            Section {
                // 스크롤 동기화
                Toggle("Sync scrolling between editor and preview", isOn: $syncScrolling)

                // 자동 저장
                Toggle("Auto save", isOn: $autosave)

                if autosave {
                    HStack {
                        Text("Auto save interval")
                        Spacer()
                        Slider(value: $autosaveInterval, in: 10...120, step: 10)
                            .frame(width: 150)
                        Text("\(Int(autosaveInterval))s")
                            .frame(width: 40)
                    }
                }
            }

            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    SettingsView()
}
