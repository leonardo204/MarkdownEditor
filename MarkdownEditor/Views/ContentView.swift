import SwiftUI
import UniformTypeIdentifiers

// 메인 콘텐츠 뷰
// 에디터와 미리보기를 분할 화면으로 표시

struct MainContentView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @StateObject private var appState = AppState()
    @StateObject private var editorActionHandler = EditorActionHandler()
    @State private var htmlContent: String = ""
    @State private var isDropTargeted: Bool = false

    private let markdownProcessor = MarkdownProcessor()

    var body: some View {
        HSplitView {
            // 에디터 패널
            VStack(spacing: 0) {
                // 에디터 헤더
                EditorHeader(theme: $appState.editorTheme)

                Divider()

                // 툴바
                ToolbarView { action in
                    editorActionHandler.performAction(action)
                }

                Divider()

                // 에디터 뷰
                EditorView(
                    content: Binding(
                        get: { documentManager.content },
                        set: { documentManager.updateContent($0) }
                    ),
                    theme: appState.editorTheme,
                    fontSize: appState.fontSize,
                    showLineNumbers: appState.showLineNumbers,
                    onTextChange: { newContent in
                        documentManager.updateContent(newContent)
                        updatePreview()
                    },
                    actionHandler: editorActionHandler
                )
            }
            .frame(minWidth: 300)

            // 미리보기 패널
            VStack(spacing: 0) {
                // 미리보기 헤더
                PreviewHeader(
                    theme: $appState.previewTheme,
                    mode: $appState.previewMode,
                    autoReload: $appState.autoReloadPreview
                )

                Divider()

                // 미리보기/HTML 뷰
                if appState.previewMode == .preview {
                    PreviewView(
                        htmlContent: htmlContent,
                        theme: appState.previewTheme
                    )
                } else {
                    HTMLSourceView(html: htmlContent, theme: appState.previewTheme)
                }
            }
            .frame(minWidth: 300)
        }
        .frame(minWidth: 800, minHeight: 600)
        .navigationTitle(documentManager.windowTitle + (documentManager.isModified ? " *" : ""))
        .onAppear {
            updatePreview()
        }
        .onChange(of: documentManager.content) { _ in
            if appState.autoReloadPreview {
                updatePreview()
            }
        }
        // 파일 드래그 앤 드롭
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleFileDrop(providers: providers)
        }
        .overlay(
            // 드롭 영역 하이라이트
            Group {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 3)
                        .background(Color.accentColor.opacity(0.1))
                }
            }
        )
    }

    private func updatePreview() {
        htmlContent = markdownProcessor.convertToHTML(documentManager.content)
    }

    // MARK: - 파일 드롭 처리
    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        // 파일 URL 로드
        provider.loadObject(ofClass: URL.self) { url, error in
            guard error == nil, let fileURL = url else {
                print("드롭 오류: \(error?.localizedDescription ?? "알 수 없는 오류")")
                return
            }

            DispatchQueue.main.async {
                documentManager.loadFile(from: fileURL)
                updatePreview()
            }
        }
        return true
    }
}

// MARK: - 에디터 헤더
struct EditorHeader: View {
    @Binding var theme: EditorTheme

    var body: some View {
        HStack {
            Text("Editor")
                .font(.headline)
                .foregroundColor(.secondary)

            Spacer()

            // 테마 선택
            Picker("Theme", selection: $theme) {
                ForEach(EditorTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - 미리보기 헤더
struct PreviewHeader: View {
    @Binding var theme: PreviewTheme
    @Binding var mode: PreviewMode
    @Binding var autoReload: Bool

    var body: some View {
        HStack {
            // 자동 새로고침 체크박스
            Toggle("Auto reload", isOn: $autoReload)
                .toggleStyle(.checkbox)
                .font(.caption)

            Spacer()

            // Preview/HTML 탭
            Picker("", selection: $mode) {
                ForEach(PreviewMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 150)

            // 테마 선택
            Picker("Theme", selection: $theme) {
                ForEach(PreviewTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - HTML 소스 뷰
struct HTMLSourceView: View {
    var html: String
    var theme: PreviewTheme

    var body: some View {
        ScrollView {
            Text(html)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(theme == .dark ? Color(NSColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1.0)) : Color.white)
    }
}

#Preview {
    MainContentView()
        .environmentObject(DocumentManager())
}
