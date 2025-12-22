import SwiftUI
import UniformTypeIdentifiers

// macOS Markdown Editor 애플리케이션
// 단일 윈도우 기반 앱 구조

@main
struct MarkdownEditorApp: App {
    @StateObject private var documentManager = DocumentManager()

    var body: some Scene {
        // 메인 윈도우
        WindowGroup {
            MainContentView()
                .environmentObject(documentManager)
        }
        .commands {
            // 파일 메뉴 커맨드
            CommandGroup(replacing: .newItem) {
                Button("새 문서") {
                    documentManager.newDocument()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Button("열기...") {
                    documentManager.openDocument()
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("저장") {
                    documentManager.saveDocument()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("다른 이름으로 저장...") {
                    documentManager.saveDocumentAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
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

// MARK: - 문서 관리자
class DocumentManager: ObservableObject {
    @Published var content: String = ""
    @Published var currentFileURL: URL?
    @Published var isModified: Bool = false
    @Published var windowTitle: String = "Untitled"

    func newDocument() {
        content = ""
        currentFileURL = nil
        isModified = false
        windowTitle = "Untitled"
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.markdown, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            loadFile(from: url)
        }
    }

    func loadFile(from url: URL) {
        do {
            let fileContent = try String(contentsOf: url, encoding: .utf8)
            content = fileContent
            currentFileURL = url
            isModified = false
            windowTitle = url.lastPathComponent
        } catch {
            print("파일 읽기 오류: \(error)")
        }
    }

    func saveDocument() {
        if let url = currentFileURL {
            saveFile(to: url)
        } else {
            saveDocumentAs()
        }
    }

    func saveDocumentAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.markdown]
        panel.nameFieldStringValue = currentFileURL?.lastPathComponent ?? "Untitled.md"

        if panel.runModal() == .OK, let url = panel.url {
            saveFile(to: url)
            currentFileURL = url
            windowTitle = url.lastPathComponent
        }
    }

    private func saveFile(to url: URL) {
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            isModified = false
        } catch {
            print("파일 저장 오류: \(error)")
        }
    }

    func updateContent(_ newContent: String) {
        if content != newContent {
            content = newContent
            isModified = true
        }
    }
}
