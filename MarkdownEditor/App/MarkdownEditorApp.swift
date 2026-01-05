import SwiftUI
import UniformTypeIdentifiers
import CoreServices

// MARK: - 디버그 로거
class DebugLogger {
    static let shared = DebugLogger()
    private var logFileURL: URL?
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private init() {
        setupLogFile()
    }

    private func setupLogFile() {
        // 샌드박스 앱 컨테이너 내 Documents 폴더 사용
        guard let containerURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let logsPath = containerURL.appendingPathComponent("Logs")
        try? FileManager.default.createDirectory(at: logsPath, withIntermediateDirectories: true)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let logFileName = "debug_\(dateFormatter.string(from: Date())).log"
        logFileURL = logsPath.appendingPathComponent(logFileName)

        log("=== MarkdownEditor Debug Log Started ===")
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        log("Version: \(version) (Build \(build)) - LogID: \(Int.random(in: 1000...9999))")
    }

    func log(_ message: String, function: String = #function) {
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"

        print(logMessage, terminator: "")

        guard let url = logFileURL, let data = logMessage.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            if let fileHandle = try? FileHandle(forWritingTo: url) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: url)
        }
    }
}

// MARK: - 파일 열기 관리자 (싱글톤)
// 핵심: 파일 URL을 먼저 저장하고, 창이 준비되면 로드
class FileOpenManager: ObservableObject {
    static let shared = FileOpenManager()

    // 열어야 할 파일 URL 큐
    private var pendingURLs: [URL] = []
    private let lock = NSLock()

    // 파일 추가 (이미 열린 파일이면 false 반환)
    @discardableResult
    func addPendingFile(_ url: URL, checkDuplicate: Bool = true) -> Bool {
        // 이미 열린 파일인지 확인
        if checkDuplicate && WindowDocumentManagerRegistry.shared.bringToFrontIfAlreadyOpen(url) {
            return false
        }

        lock.lock()
        defer { lock.unlock() }
        pendingURLs.append(url)
        DebugLogger.shared.log("FileOpenManager: Added pending file: \(url.lastPathComponent), queue: \(pendingURLs.count)")
        return true
    }

    // 다음 파일 가져오기 (창에서 호출)
    func popPendingFile() -> URL? {
        lock.lock()
        defer { lock.unlock() }
        guard !pendingURLs.isEmpty else { return nil }
        let url = pendingURLs.removeFirst()
        DebugLogger.shared.log("FileOpenManager: Popped file: \(url.lastPathComponent), remaining: \(pendingURLs.count)")
        return url
    }

    // 현재 pending 파일 개수
    var pendingCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pendingURLs.count
    }

    // 첫 번째 pending 파일 확인 (제거하지 않음)
    func peekPendingFile() -> URL? {
        lock.lock()
        defer { lock.unlock() }
        return pendingURLs.first
    }
}

// MARK: - 새 창 열기 트리거 (싱글톤)
class NewWindowTrigger: ObservableObject {
    static let shared = NewWindowTrigger()
    @Published var counter: Int = 0

    // 탭으로 열기 요청 시 사용
    var openAsTab: Bool = false
    var sourceWindow: NSWindow?

    func trigger() {
        DebugLogger.shared.log("NewWindowTrigger.trigger() called")
        counter += 1
    }

    // 새 탭으로 열기
    func triggerNewTab() {
        DebugLogger.shared.log("NewWindowTrigger.triggerNewTab() called")
        openAsTab = true
        sourceWindow = NSApp.keyWindow
        counter += 1
    }

    // 상태 리셋
    func reset() {
        openAsTab = false
        sourceWindow = nil
    }
}

// macOS Markdown Editor 애플리케이션
// 단일 윈도우 기반 앱 구조

@main
struct MarkdownEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @FocusedValue(\.documentManager) var focusedDocumentManager
    @FocusedValue(\.tabManager) var focusedTabManager
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var newWindowTrigger = NewWindowTrigger.shared

    init() {
        // 앱 초기화 시점에 상태 복원 완전 비활성화
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        // 커스텀 탭 바 사용으로 네이티브 탭 비활성화
        NSWindow.allowsAutomaticWindowTabbing = false
        DebugLogger.shared.log("MarkdownEditorApp.init()")
    }

    var body: some Scene {
        // 메인 윈도우
        WindowGroup(id: "main") {
            MainContentView()
                .onOpenURL { url in
                    // SwiftUI 네이티브 방식으로 파일 URL 수신
                    DebugLogger.shared.log("onOpenURL received: \(url.lastPathComponent)")
                    handleOpenURL(url)
                }
        }
        .onChange(of: newWindowTrigger.counter) { _ in
            DebugLogger.shared.log("WindowGroup onChange - opening new window")
            openWindow(id: "main")
        }
        .commands {
            // 파일 메뉴 커맨드
            CommandGroup(replacing: .newItem) {
                Button("새 문서") {
                    focusedDocumentManager?.newDocumentWithConfirmation()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("새 탭") {
                    focusedTabManager?.addNewTab()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("새 윈도우") {
                    NewWindowTrigger.shared.trigger()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(after: .newItem) {
                Button("열기...") {
                    openDocumentInTab()
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("탭 닫기") {
                    _ = focusedTabManager?.closeCurrentTab()
                }
                .keyboardShortcut("w", modifiers: .command)

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

            // 탭 이동 명령
            CommandGroup(after: .windowArrangement) {
                Button("다음 탭") {
                    focusedTabManager?.selectNextTab()
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])

                Button("이전 탭") {
                    focusedTabManager?.selectPreviousTab()
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])

                Divider()

                // 탭 번호로 이동 (1-9)
                ForEach(1..<10, id: \.self) { number in
                    Button("탭 \(number)") {
                        focusedTabManager?.selectTab(number: number)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: .command)
                }
            }

            TextEditingCommands()
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }

    // onOpenURL 핸들러
    private func handleOpenURL(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        guard ext == "md" || ext == "markdown" || ext == "txt" || ext == "text" else {
            DebugLogger.shared.log("onOpenURL: Invalid extension: \(ext)")
            return
        }

        _ = url.startAccessingSecurityScopedResource()

        // 이미 열린 파일인지 확인
        if WindowTabManagerRegistry.shared.bringToFrontIfAlreadyOpen(url) {
            return
        }

        // 현재 키 윈도우의 TabManager에서 열기
        let openInNewTab = UserDefaults.standard.object(forKey: "openFilesInNewTab") as? Bool ?? true

        if let keyWindow = NSApp.keyWindow,
           let tabManager = WindowTabManagerRegistry.shared.tabManager(for: keyWindow) {
            if openInNewTab {
                tabManager.openFileInNewTab(url: url)
            } else {
                // 새 윈도우에서 열기
                FileOpenManager.shared.addPendingFile(url, checkDuplicate: false)
                NewWindowTrigger.shared.trigger()
            }
        } else {
            // 윈도우가 없으면 pending에 추가
            FileOpenManager.shared.addPendingFile(url, checkDuplicate: false)
        }
    }

    // 파일 열기 (탭/윈도우 설정에 따라)
    private func openDocumentInTab() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.markdown, .plainText]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            let urls = panel.urls
            guard !urls.isEmpty else { return }

            let openInNewTab = UserDefaults.standard.object(forKey: "openFilesInNewTab") as? Bool ?? true

            for url in urls {
                // 이미 열린 파일인지 확인
                if WindowTabManagerRegistry.shared.bringToFrontIfAlreadyOpen(url) {
                    continue
                }

                if openInNewTab {
                    // 현재 윈도우의 TabManager에서 열기
                    if let keyWindow = NSApp.keyWindow,
                       let tabManager = WindowTabManagerRegistry.shared.tabManager(for: keyWindow) {
                        tabManager.openFileInNewTab(url: url)
                    }
                } else {
                    // 새 윈도우에서 열기
                    FileOpenManager.shared.addPendingFile(url, checkDuplicate: false)
                    NewWindowTrigger.shared.trigger()
                }
            }
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {

    private let hasAskedDefaultAppKey = "HasAskedToSetAsDefaultApp"
    private let bundleIdentifier = "com.zerolive.MarkdownEditor"

    // 콜드 스타트 여부 추적
    private var isFirstLaunch = true
    private var hasProcessedInitialFiles = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        // 가장 먼저 실행되는 시점 - 상태 복원 비활성화
        DebugLogger.shared.log("applicationWillFinishLaunching")
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")

        // 저장된 상태 디렉토리 삭제 (이전 세션 창 복원 방지)
        clearSavedState()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DebugLogger.shared.log("applicationDidFinishLaunching - pending files: \(FileOpenManager.shared.pendingCount)")

        // 첫 실행 시 기본 앱 설정 제안
        checkAndOfferDefaultApp()

        isFirstLaunch = false
    }

    // 저장된 상태 삭제
    private func clearSavedState() {
        if let bundleID = Bundle.main.bundleIdentifier {
            let savedStatePath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Saved Application State")
                .appendingPathComponent("\(bundleID).savedState")

            if let path = savedStatePath, FileManager.default.fileExists(atPath: path.path) {
                try? FileManager.default.removeItem(at: path)
                DebugLogger.shared.log("Cleared saved state")
            }
        }
    }

    // MARK: - 파일 열기 이벤트 처리 (더블클릭, Open With)

    func application(_ application: NSApplication, open urls: [URL]) {
        DebugLogger.shared.log("application(_:open:) with \(urls.count) URLs")

        let validURLs = urls.filter { url in
            let ext = url.pathExtension.lowercased()
            return ext == "md" || ext == "markdown" || ext == "txt" || ext == "text"
        }

        guard !validURLs.isEmpty else {
            DebugLogger.shared.log("No valid URLs")
            return
        }

        // Security-scoped resource 접근
        for url in validURLs {
            _ = url.startAccessingSecurityScopedResource()
        }

        let openInNewTab = UserDefaults.standard.object(forKey: "openFilesInNewTab") as? Bool ?? true

        // 현재 키 윈도우의 TabManager 찾기
        if let keyWindow = NSApp.keyWindow,
           let tabManager = WindowTabManagerRegistry.shared.tabManager(for: keyWindow) {
            for url in validURLs {
                // 이미 열린 파일인지 확인
                if WindowTabManagerRegistry.shared.bringToFrontIfAlreadyOpen(url) {
                    continue
                }

                if openInNewTab {
                    tabManager.openFileInNewTab(url: url)
                } else {
                    FileOpenManager.shared.addPendingFile(url, checkDuplicate: false)
                    NewWindowTrigger.shared.trigger()
                }
            }
        } else {
            // 윈도우가 없으면 pending에 추가하고 윈도우 생성
            for url in validURLs {
                FileOpenManager.shared.addPendingFile(url, checkDuplicate: false)
            }
            DispatchQueue.main.async {
                self.tryLoadPendingFilesIntoTabs()
            }
        }
    }

    // pending 파일들을 기존 빈 탭에 로드하거나 새 탭 생성
    private func tryLoadPendingFilesIntoTabs() {
        DebugLogger.shared.log("tryLoadPendingFilesIntoTabs - pending: \(FileOpenManager.shared.pendingCount)")

        // 키 윈도우의 TabManager 찾기
        if let keyWindow = NSApp.keyWindow,
           let tabManager = WindowTabManagerRegistry.shared.tabManager(for: keyWindow) {
            // 현재 탭이 비어있으면 첫 번째 파일 로드
            if let currentTab = tabManager.currentTab,
               currentTab.documentManager.currentFileURL == nil && currentTab.documentManager.content.isEmpty {
                if let url = FileOpenManager.shared.popPendingFile() {
                    currentTab.documentManager.loadFile(from: url)
                }
            }

            // 나머지 파일들은 새 탭에서 열기
            while let url = FileOpenManager.shared.popPendingFile() {
                tabManager.openFileInNewTab(url: url)
            }
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
    private var registry: [ObjectIdentifier: (window: NSWindow, manager: DocumentManager)] = [:]

    func register(_ documentManager: DocumentManager, for window: NSWindow) {
        registry[ObjectIdentifier(window)] = (window, documentManager)
    }

    func unregister(for window: NSWindow) {
        registry.removeValue(forKey: ObjectIdentifier(window))
    }

    func documentManager(for window: NSWindow) -> DocumentManager? {
        return registry[ObjectIdentifier(window)]?.manager
    }

    var allDocumentManagers: [DocumentManager] {
        return registry.values.map { $0.manager }
    }

    // 이미 열린 파일인지 확인하고, 열려있으면 해당 창 반환
    func findWindow(for fileURL: URL) -> NSWindow? {
        for (_, entry) in registry {
            if let openedURL = entry.manager.currentFileURL,
               openedURL.standardizedFileURL == fileURL.standardizedFileURL {
                return entry.window
            }
        }
        return nil
    }

    // 이미 열린 파일이면 해당 창을 앞으로 가져오고 true 반환
    func bringToFrontIfAlreadyOpen(_ fileURL: URL, closeEmptyWindow: Bool = true) -> Bool {
        if let existingWindow = findWindow(for: fileURL) {
            DebugLogger.shared.log("File already open: \(fileURL.lastPathComponent)")

            // 해당 창을 앞으로 가져오기
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            // 알림 표시 (약간 지연 후 - 빈 창이 레지스트리에 등록될 시간 확보)
            DebugLogger.shared.log("Scheduling alert in 0.3s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                DebugLogger.shared.log("Showing duplicate file alert")

                let alert = NSAlert()
                alert.messageText = "이미 열린 파일입니다"
                alert.informativeText = "\"\(fileURL.lastPathComponent)\" 파일이 이미 다른 창에서 열려 있습니다."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "확인")
                alert.runModal()

                DebugLogger.shared.log("Alert dismissed, closeEmptyWindow=\(closeEmptyWindow)")

                // 알림 확인 후 빈 창 찾아서 닫기
                if closeEmptyWindow {
                    WindowDocumentManagerRegistry.shared.closeEmptyWindows(except: existingWindow)
                }
            }

            return true
        }
        return false
    }

    // 빈 창 닫기 (특정 창 제외)
    func closeEmptyWindows(except keepWindow: NSWindow) {
        DebugLogger.shared.log("closeEmptyWindows: checking \(NSApp.windows.count) windows")

        for window in NSApp.windows {
            let dm = documentManager(for: window)
            let isRegistered = dm != nil
            let isEmpty = dm?.currentFileURL == nil && (dm?.content.isEmpty ?? true)
            let isKeepWindow = window === keepWindow

            DebugLogger.shared.log("  Window: registered=\(isRegistered), isEmpty=\(isEmpty), isKeepWindow=\(isKeepWindow)")

            if !isKeepWindow && isRegistered && isEmpty {
                DebugLogger.shared.log("  -> Closing this empty window")
                window.close()
            }
        }
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
        panel.allowsMultipleSelection = true  // 여러 파일 선택 허용
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            let urls = panel.urls
            guard !urls.isEmpty else { return }

            // 이미 열린 파일 필터링
            var urlsToOpen: [URL] = []
            for url in urls {
                if !WindowDocumentManagerRegistry.shared.bringToFrontIfAlreadyOpen(url) {
                    urlsToOpen.append(url)
                }
            }

            guard !urlsToOpen.isEmpty else { return }

            // 현재 창이 비어있으면 첫 번째 파일을 현재 창에서 열기
            if currentFileURL == nil && content.isEmpty {
                loadFile(from: urlsToOpen[0])
                // 나머지 파일들은 새 탭/윈도우에서 열기
                if urlsToOpen.count > 1 {
                    openFilesInNewTabsOrWindows(Array(urlsToOpen.dropFirst()))
                }
            } else {
                // 현재 문서가 있으면 모든 파일을 새 탭/윈도우에서 열기
                openFilesInNewTabsOrWindows(urlsToOpen)
            }
        }
    }

    // 여러 파일을 새 탭/윈도우에서 열기
    private func openFilesInNewTabsOrWindows(_ urls: [URL]) {
        let openInNewTab = UserDefaults.standard.object(forKey: "openFilesInNewTab") as? Bool ?? true
        let currentWindow = NSApp.keyWindow

        for url in urls {
            FileOpenManager.shared.addPendingFile(url, checkDuplicate: false)
        }

        for (index, _) in urls.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                if openInNewTab {
                    NewWindowTrigger.shared.openAsTab = true
                    NewWindowTrigger.shared.sourceWindow = currentWindow
                }
                NewWindowTrigger.shared.trigger()
            }
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

            // quarantine 속성 제거 (파일 열 때 샌드박스가 추가하는 속성)
            removeQuarantineAttribute(from: url)
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

            // quarantine 속성 제거 (샌드박스 앱에서 저장 시 추가되는 속성)
            removeQuarantineAttribute(from: url)
        } catch {
            print("파일 저장 오류: \(error)")
        }
    }

    // quarantine 속성 제거
    private func removeQuarantineAttribute(from url: URL) {
        let path = url.path
        path.withCString { cPath in
            removexattr(cPath, "com.apple.quarantine", 0)
        }
    }

    func updateContent(_ newContent: String) {
        content = newContent
        // savedContent와 비교하여 수정 여부 판단
        isModified = (content != savedContent)
    }
}
