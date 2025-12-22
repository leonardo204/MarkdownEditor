import SwiftUI
import UniformTypeIdentifiers
import CoreServices

// MARK: - Notification 확장
extension Notification.Name {
    static let openFileInNewWindow = Notification.Name("openFileInNewWindow")
}

// macOS Markdown Editor 애플리케이션
// 단일 윈도우 기반 앱 구조

@main
struct MarkdownEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @FocusedValue(\.documentManager) var focusedDocumentManager
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // 메인 윈도우 - 각 윈도우마다 독립적인 DocumentManager 생성
        WindowGroup(id: "main") {
            MainContentView()
                .onReceive(NotificationCenter.default.publisher(for: .openFileInNewWindow)) { _ in
                    // 새 창 열기 (PendingFileManager에서 파일 URL 가져옴)
                    openWindow(id: "main")
                }
        }
        .commands {
            // 파일 메뉴 커맨드 - FocusedValue를 통해 현재 윈도우의 documentManager 접근
            CommandGroup(replacing: .newItem) {
                Button("새 문서") {
                    focusedDocumentManager?.newDocumentWithConfirmation()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Button("열기...") {
                    focusedDocumentManager?.openDocumentWithConfirmation()
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("저장") {
                    focusedDocumentManager?.saveDocument()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("다른 이름으로 저장...") {
                    focusedDocumentManager?.saveDocumentAs()
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

// MARK: - App Delegate (앱 종료 시 저장 확인 + 첫 실행 시 기본 앱 설정)
class AppDelegate: NSObject, NSApplicationDelegate {

    private let hasAskedDefaultAppKey = "HasAskedToSetAsDefaultApp"
    private let bundleIdentifier = "com.zerolive.MarkdownEditor"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 첫 실행 시 기본 앱 설정 제안
        checkAndOfferDefaultApp()
    }

    // MARK: - 파일 열기 이벤트 처리 (더블클릭, Open With)

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            let ext = url.pathExtension.lowercased()
            guard ext == "md" || ext == "markdown" || ext == "txt" || ext == "text" else {
                continue
            }

            // Security-scoped resource 접근 시작
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // PendingFileManager에 추가하고 새 창 열기
            PendingFileManager.shared.addPendingFile(url)
            NotificationCenter.default.post(name: .openFileInNewWindow, object: url)
        }
    }

    // MARK: - 기본 앱 설정 확인

    private func checkAndOfferDefaultApp() {
        // 이미 물어봤으면 스킵
        if UserDefaults.standard.bool(forKey: hasAskedDefaultAppKey) {
            return
        }

        // 현재 .md 파일의 기본 앱 확인
        let markdownUTI = "net.daringfireball.markdown" as CFString
        if let currentHandler = LSCopyDefaultRoleHandlerForContentType(markdownUTI, .all)?.takeRetainedValue() as String? {
            // 이미 이 앱이 기본 앱이면 스킵
            if currentHandler == bundleIdentifier {
                UserDefaults.standard.set(true, forKey: hasAskedDefaultAppKey)
                return
            }
        }

        // 기본 앱 설정 다이얼로그 표시
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            showDefaultAppAlert()
        }
    }

    private func showDefaultAppAlert() {
        let alert = NSAlert()
        alert.messageText = "Markdown Editor를 기본 앱으로 설정하시겠습니까?"
        alert.informativeText = ".md 및 .markdown 파일을 더블클릭하면 이 앱으로 열립니다."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "기본 앱으로 설정")
        alert.addButton(withTitle: "나중에")
        alert.addButton(withTitle: "다시 묻지 않기")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:  // 기본 앱으로 설정
            setAsDefaultApp()
            UserDefaults.standard.set(true, forKey: hasAskedDefaultAppKey)
        case .alertSecondButtonReturn:  // 나중에
            // 다음 실행 시 다시 물어봄
            break
        case .alertThirdButtonReturn:  // 다시 묻지 않기
            UserDefaults.standard.set(true, forKey: hasAskedDefaultAppKey)
        default:
            break
        }
    }

    private func setAsDefaultApp() {
        let markdownUTI = "net.daringfireball.markdown" as CFString
        let publicTextUTI = "public.plain-text" as CFString

        // .md, .markdown 파일 연결
        LSSetDefaultRoleHandlerForContentType(markdownUTI, .all, bundleIdentifier as CFString)

        // 추가로 일반 텍스트도 에디터로 설정 (선택적)
        LSSetDefaultRoleHandlerForContentType(publicTextUTI, .editor, bundleIdentifier as CFString)

        // 완료 알림
        let successAlert = NSAlert()
        successAlert.messageText = "설정 완료"
        successAlert.informativeText = "Markdown Editor가 .md 파일의 기본 앱으로 설정되었습니다."
        successAlert.alertStyle = .informational
        successAlert.addButton(withTitle: "확인")
        successAlert.runModal()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // 모든 윈도우의 수정 상태 확인
        for window in NSApp.windows {
            if let documentManager = findDocumentManager(in: window),
               documentManager.isModified {

                // 해당 윈도우를 앞으로 가져오기
                window.makeKeyAndOrderFront(nil)

                // 저장 확인 다이얼로그 표시
                let response = showSaveConfirmationAlert(for: documentManager.windowTitle)

                switch response {
                case .alertFirstButtonReturn:  // 저장
                    documentManager.saveDocument()
                case .alertSecondButtonReturn:  // 저장 안 함
                    continue
                case .alertThirdButtonReturn:  // 취소
                    return .terminateCancel
                default:
                    return .terminateCancel
                }
            }
        }
        return .terminateNow
    }

    // NSWindow에서 DocumentManager 찾기
    private func findDocumentManager(in window: NSWindow) -> DocumentManager? {
        // SwiftUI 뷰에서 DocumentManager 접근은 FocusedValue를 통해 하므로
        // 여기서는 NotificationCenter를 통해 접근하거나, 윈도우별 저장소 사용
        // 간단한 방법: 윈도우 컨트롤러나 뷰 계층에서 찾기
        return WindowDocumentManagerRegistry.shared.documentManager(for: window)
    }

    private func showSaveConfirmationAlert(for title: String) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = "\"\(title)\"의 변경 사항을 저장하시겠습니까?"
        alert.informativeText = "저장하지 않으면 변경 사항이 손실됩니다."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "저장")
        alert.addButton(withTitle: "저장 안 함")
        alert.addButton(withTitle: "취소")
        return alert.runModal()
    }
}

// MARK: - 윈도우별 DocumentManager 레지스트리
class WindowDocumentManagerRegistry {
    static let shared = WindowDocumentManagerRegistry()
    private var registry: [ObjectIdentifier: DocumentManager] = [:]

    func register(_ documentManager: DocumentManager, for window: NSWindow) {
        registry[ObjectIdentifier(window)] = documentManager
    }

    func unregister(for window: NSWindow) {
        registry.removeValue(forKey: ObjectIdentifier(window))
    }

    func documentManager(for window: NSWindow) -> DocumentManager? {
        return registry[ObjectIdentifier(window)]
    }

    var allDocumentManagers: [DocumentManager] {
        return Array(registry.values)
    }
}

// MARK: - 문서 관리자
class DocumentManager: ObservableObject {
    @Published var content: String = ""
    @Published var currentFileURL: URL?
    @Published var isModified: Bool = false
    @Published var windowTitle: String = "Untitled"

    // 저장된 원본 내용 (수정 여부 판단용)
    private var savedContent: String = ""

    // MARK: - 저장 확인 다이얼로그

    /// 변경 사항이 있으면 저장 확인 후 작업 수행
    /// - Returns: 작업을 계속할 수 있으면 true, 취소하면 false
    @discardableResult
    func confirmSaveIfNeeded() -> Bool {
        guard isModified else { return true }

        let alert = NSAlert()
        alert.messageText = "변경 사항을 저장하시겠습니까?"
        alert.informativeText = "저장하지 않으면 변경 사항이 손실됩니다."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "저장")
        alert.addButton(withTitle: "저장 안 함")
        alert.addButton(withTitle: "취소")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:  // 저장
            saveDocument()
            return true
        case .alertSecondButtonReturn:  // 저장 안 함
            return true
        case .alertThirdButtonReturn:  // 취소
            return false
        default:
            return false
        }
    }

    // MARK: - 문서 작업 (저장 확인 포함)

    func newDocumentWithConfirmation() {
        guard confirmSaveIfNeeded() else { return }
        newDocument()
    }

    func openDocumentWithConfirmation() {
        guard confirmSaveIfNeeded() else { return }
        openDocument()
    }

    func loadFileWithConfirmation(from url: URL) {
        guard confirmSaveIfNeeded() else { return }
        loadFile(from: url)
    }

    // MARK: - 기본 문서 작업

    func newDocument() {
        content = ""
        savedContent = ""
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
            savedContent = fileContent
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
            savedContent = content
            isModified = false
        } catch {
            print("파일 저장 오류: \(error)")
        }
    }

    func updateContent(_ newContent: String) {
        content = newContent
        // savedContent와 비교하여 수정 여부 판단
        isModified = (content != savedContent)
    }
}
