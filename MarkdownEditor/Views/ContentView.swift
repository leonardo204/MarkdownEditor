import SwiftUI
import UniformTypeIdentifiers

// 메인 콘텐츠 뷰
// 에디터와 미리보기를 분할 화면으로 표시

struct ContentView: View {
    @Binding var document: MarkdownDocument
    @StateObject private var appState = AppState()
    @State private var htmlContent: String = ""
    @State private var isDropTargeted: Bool = false

    private let markdownProcessor = MarkdownProcessor()

    // 지원하는 파일 타입
    private let supportedTypes: [UTType] = [.markdown, .plainText]

    var body: some View {
        HSplitView {
            // 에디터 패널
            VStack(spacing: 0) {
                // 에디터 헤더
                EditorHeader(theme: $appState.editorTheme)

                Divider()

                // 에디터 뷰
                EditorView(
                    content: $document.content,
                    theme: appState.editorTheme,
                    fontSize: appState.fontSize,
                    showLineNumbers: appState.showLineNumbers,
                    onTextChange: { _ in
                        updatePreview()
                    }
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
        .onAppear {
            updatePreview()
        }
        .onChange(of: document.content) { _ in
            if appState.autoReloadPreview {
                updatePreview()
            }
        }
        // 파일 드래그 앤 드롭
        .onDrop(of: supportedTypes, isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
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
        htmlContent = markdownProcessor.convertToHTML(document.content)
    }

    // MARK: - 파일 드롭 처리
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        // 파일 URL 로드
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard error == nil,
                      let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }

                // 파일 읽기
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    DispatchQueue.main.async {
                        document.content = content
                        updatePreview()
                    }
                }
            }
            return true
        }

        // 텍스트 데이터 로드
        for type in [UTType.markdown, UTType.plainText] {
            if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, error in
                    guard error == nil else { return }

                    var content: String?

                    if let data = item as? Data {
                        content = String(data: data, encoding: .utf8)
                    } else if let string = item as? String {
                        content = string
                    }

                    if let content = content {
                        DispatchQueue.main.async {
                            document.content = content
                            updatePreview()
                        }
                    }
                }
                return true
            }
        }

        return false
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
    ContentView(document: .constant(MarkdownDocument(content: """
    # Hello World

    This is a **Markdown** preview with *italic* and ~~strikethrough~~.

    ## Code Example

    ```swift
    let greeting = "Hello, World!"
    print(greeting)
    ```

    ## Table

    | Name | Age |
    |------|-----|
    | Alice | 25 |
    | Bob | 30 |

    ## List

    - Item 1
    - Item 2
      - Nested item

    ## Mermaid Diagram

    ```mermaid
    graph TD
        A[Start] --> B{Decision}
        B -->|Yes| C[OK]
        B -->|No| D[Cancel]
    ```

    ## Math

    Inline math: $E = mc^2$

    Block math:

    $$
    \\int_{-\\infty}^{\\infty} e^{-x^2} dx = \\sqrt{\\pi}
    $$
    """)))
}
