import SwiftUI

// macOS Markdown Editor 애플리케이션
// SwiftUI Document-based App 구조

@main
struct MarkdownEditorApp: App {
    var body: some Scene {
        // 문서 기반 앱 구성
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document)
        }
        .commands {
            // 파일 메뉴 커맨드
            CommandGroup(replacing: .newItem) {
                Button("새 문서") {
                    NSDocumentController.shared.newDocument(nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            // 텍스트 편집 커맨드
            TextEditingCommands()
        }

        // 설정 화면
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
