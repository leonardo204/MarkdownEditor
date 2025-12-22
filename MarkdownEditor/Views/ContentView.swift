import SwiftUI

// 메인 콘텐츠 뷰
// 에디터와 미리보기를 분할 화면으로 표시

struct ContentView: View {
    @Binding var document: MarkdownDocument
    @StateObject private var appState = AppState()
    @State private var htmlContent: String = ""

    private let markdownProcessor = MarkdownProcessor()

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
    }

    private func updatePreview() {
        htmlContent = markdownProcessor.convertToHTML(document.content)
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
