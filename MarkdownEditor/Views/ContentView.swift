import SwiftUI

// 메인 콘텐츠 뷰
// 에디터와 미리보기를 분할 화면으로 표시

struct ContentView: View {
    @Binding var document: MarkdownDocument

    var body: some View {
        HSplitView {
            // 에디터 패널
            EditorPanel(content: $document.content)
                .frame(minWidth: 300)

            // 미리보기 패널
            PreviewPanel(content: document.content)
                .frame(minWidth: 300)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

// 에디터 패널 (임시 구현)
struct EditorPanel: View {
    @Binding var content: String

    var body: some View {
        VStack(spacing: 0) {
            // 에디터 헤더
            HStack {
                Text("Editor")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // 텍스트 에디터
            TextEditor(text: $content)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.textBackgroundColor))
        }
    }
}

// 미리보기 패널 (임시 구현)
struct PreviewPanel: View {
    var content: String

    var body: some View {
        VStack(spacing: 0) {
            // 미리보기 헤더
            HStack {
                Text("Preview")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()

                // Preview/HTML 탭
                Picker("", selection: .constant("preview")) {
                    Text("Preview").tag("preview")
                    Text("HTML").tag("html")
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // 미리보기 콘텐츠 (임시)
            ScrollView {
                Text(content)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(NSColor.textBackgroundColor))
        }
    }
}

#Preview {
    ContentView(document: .constant(MarkdownDocument(content: "# Hello World\n\nThis is a **Markdown** preview.")))
}
