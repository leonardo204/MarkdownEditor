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
        #if DEBUG
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
        #endif
    }
}

// macOS Markdown Editor 애플리케이션
// 순수 AppKit 생명주기 - SwiftUI App 프로토콜 미사용으로 메뉴 바 충돌 방지

@main
struct MarkdownEditorApp {
    static let appDelegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = appDelegate
        app.run()
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {

    private let hasAskedDefaultAppKey = "HasAskedToSetAsDefaultApp"
    private let bundleIdentifier = "com.zerolive.MarkdownEditor"

    // 환경설정 윈도우 관리
    private var settingsWindowController: NSWindowController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // 가장 먼저 실행되는 시점 - 상태 복원 비활성화
        DebugLogger.shared.log("applicationWillFinishLaunching")
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")

        // 네이티브 윈도우 탭 활성화 (Safari, Finder 스타일)
        NSWindow.allowsAutomaticWindowTabbing = true

        // 저장된 상태 디렉토리 삭제 (이전 세션 창 복원 방지)
        clearSavedState()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DebugLogger.shared.log("applicationDidFinishLaunching")

        // 메뉴 설정
        setupMainMenu()

        // 첫 실행 시 기본 앱 설정 제안
        checkAndOfferDefaultApp()

        // 첫 윈도우 생성 (TabService가 윈도우 관리)
        if TabService.shared.managedWindowsCount == 0 {
            DebugLogger.shared.log("Creating initial document window")
            TabService.shared.createNewDocument()
        }

        NSApp.activate(ignoringOtherApps: true)
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

        // TabService를 통해 파일 열기
        for url in validURLs {
            TabService.shared.openDocument(url: url)
        }

        // 앱을 전면으로 가져오기
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - 메뉴 설정

    private func setupMainMenu() {
        // 새 메인 메뉴 생성
        let mainMenu = NSMenu()

        // App 메뉴
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About MarkdownEditor", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences(_:)), keyEquivalent: ","))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Hide MarkdownEditor", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit MarkdownEditor", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File 메뉴
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")

        // 새 탭 (Cmd+T)
        let newTabItem = NSMenuItem(title: "새 탭", action: #selector(newDocument(_:)), keyEquivalent: "t")
        newTabItem.target = self
        fileMenu.addItem(newTabItem)

        // 새 문서 (Cmd+N)
        let newDocItem = NSMenuItem(title: "새 문서", action: #selector(newDocument(_:)), keyEquivalent: "n")
        newDocItem.target = self
        fileMenu.addItem(newDocItem)

        // 새 윈도우
        let newWindowItem = NSMenuItem(title: "새 윈도우", action: #selector(newWindow(_:)), keyEquivalent: "N")
        newWindowItem.keyEquivalentModifierMask = [.command, .shift]
        newWindowItem.target = self
        fileMenu.addItem(newWindowItem)

        fileMenu.addItem(NSMenuItem.separator())

        // 열기
        let openItem = NSMenuItem(title: "열기...", action: #selector(openDocument(_:)), keyEquivalent: "o")
        openItem.target = self
        fileMenu.addItem(openItem)

        fileMenu.addItem(NSMenuItem.separator())

        // 닫기
        let closeItem = NSMenuItem(title: "닫기", action: #selector(closeDocument(_:)), keyEquivalent: "w")
        closeItem.target = self
        fileMenu.addItem(closeItem)

        fileMenu.addItem(NSMenuItem.separator())

        // 저장
        let saveItem = NSMenuItem(title: "저장", action: #selector(saveDocument(_:)), keyEquivalent: "s")
        saveItem.target = self
        fileMenu.addItem(saveItem)

        // 다른 이름으로 저장
        let saveAsItem = NSMenuItem(title: "다른 이름으로 저장...", action: #selector(saveDocumentAs(_:)), keyEquivalent: "S")
        saveAsItem.keyEquivalentModifierMask = [.command, .shift]
        saveAsItem.target = self
        fileMenu.addItem(saveAsItem)

        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // Edit 메뉴
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // View 메뉴
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        let toggleTabBarItem = NSMenuItem(title: "탭 바 표시/숨기기", action: #selector(toggleTabBar(_:)), keyEquivalent: "")
        toggleTabBarItem.target = self
        viewMenu.addItem(toggleTabBarItem)
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // Window 메뉴 (App Store 가이드라인 4 준수 - 윈도우 재오픈 메뉴 항목 필수)
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")

        // 새 윈도우 - 윈도우가 모두 닫혀있어도 항상 활성화 (target = self)
        let windowNewItem = NSMenuItem(title: "New Window", action: #selector(newWindow(_:)), keyEquivalent: "")
        windowNewItem.target = self
        windowMenu.addItem(windowNewItem)
        windowMenu.addItem(NSMenuItem.separator())

        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(NSMenuItem(title: "Show All Tabs", action: #selector(NSWindow.toggleTabOverview(_:)), keyEquivalent: ""))
        let mergeItem = NSMenuItem(title: "Merge All Windows", action: #selector(NSWindow.mergeAllWindows(_:)), keyEquivalent: "")
        windowMenu.addItem(mergeItem)
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(NSMenuItem(title: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: ""))
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        // Help 메뉴
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
        NSApp.helpMenu = helpMenu
    }

    @objc func showPreferences(_ sender: Any?) {
        // 기존 윈도우가 있으면 재사용
        if let existingController = settingsWindowController, let window = existingController.window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable]
        window.setFrameAutosaveName("SettingsWindow")
        window.center()

        settingsWindowController = NSWindowController(window: window)
        settingsWindowController?.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    @objc func toggleTabBar(_ sender: Any?) {
        NSApp.keyWindow?.toggleTabBar(nil)
    }

    // MARK: - 메뉴 액션

    @objc func newDocument(_ sender: Any?) {
        DebugLogger.shared.log("Menu: New Document")

        // 현재 윈도우가 문서 윈도우이면 탭으로 추가 (Settings 윈도우 등 제외)
        if let keyWindow = NSApp.keyWindow,
           TabService.shared.managedWindows.contains(where: { $0.window === keyWindow }),
           let newWindow = TabService.shared.newWindowForTab(orderFront: false) {
            keyWindow.addTabbedWindow(newWindow, ordered: .above)
            newWindow.makeKeyAndOrderFront(nil)
        } else {
            TabService.shared.createNewDocument()
        }
    }

    @objc func newWindow(_ sender: Any?) {
        DebugLogger.shared.log("Menu: New Window")
        TabService.shared.createNewDocument()
    }

    @objc func openDocument(_ sender: Any?) {
        DebugLogger.shared.log("Menu: Open Document")

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.plainText]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            for url in panel.urls {
                TabService.shared.openDocument(url: url)
            }
        }
    }

    @objc func closeDocument(_ sender: Any?) {
        DebugLogger.shared.log("Menu: Close Document")
        NSApp.keyWindow?.performClose(nil)
    }

    @objc func saveDocument(_ sender: Any?) {
        DebugLogger.shared.log("Menu: Save Document")
        if let keyWindow = NSApp.keyWindow,
           let controller = TabService.shared.managedWindows.first(where: { $0.window === keyWindow })?.controller {
            controller.documentManager.saveDocument()
        }
    }

    @objc func saveDocumentAs(_ sender: Any?) {
        DebugLogger.shared.log("Menu: Save Document As")
        if let keyWindow = NSApp.keyWindow,
           let controller = TabService.shared.managedWindows.first(where: { $0.window === keyWindow })?.controller {
            controller.documentManager.saveDocumentAs()
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
        // TabService를 통해 모든 윈도우 저장 확인
        return TabService.shared.confirmCloseAll() ? .terminateNow : .terminateCancel
    }

    // MARK: - 윈도우 생명주기 관리 (App Store 가이드라인 4 준수)

    /// 마지막 윈도우가 닫혀도 앱을 종료하지 않음
    /// 사용자가 메뉴 또는 Dock 아이콘으로 새 윈도우를 열 수 있도록 유지
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    /// Dock 아이콘 클릭 시 윈도우 재생성
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            DebugLogger.shared.log("Dock icon clicked with no visible windows - creating new document")
            TabService.shared.createNewDocument()
        }
        return true
    }

    /// Dock 아이콘 우클릭 메뉴 - 윈도우가 없을 때도 새 윈도우 생성 가능
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let newWindowItem = NSMenuItem(title: "New Window", action: #selector(newWindow(_:)), keyEquivalent: "")
        newWindowItem.target = self
        menu.addItem(newWindowItem)
        return menu
    }

    // MARK: - 메뉴 항목 활성화/비활성화 관리

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(newDocument(_:)),
             #selector(newWindow(_:)),
             #selector(openDocument(_:)),
             #selector(showPreferences(_:)):
            // 새 문서/윈도우 생성 및 열기는 항상 활성화
            return true
        case #selector(saveDocument(_:)),
             #selector(saveDocumentAs(_:)),
             #selector(closeDocument(_:)),
             #selector(toggleTabBar(_:)):
            // 저장/닫기는 윈도우가 있을 때만 활성화
            return NSApp.keyWindow != nil
        default:
            return true
        }
    }

    // NSWindow에서 DocumentManager 찾기 (TabService 사용)
    private func findDocumentManager(in window: NSWindow) -> DocumentManager? {
        return TabService.shared.managedWindows.first(where: { $0.window === window })?.controller.documentManager
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

// MARK: - 문서 관리자
class DocumentManager: ObservableObject {
    @Published var content: String = ""
    @Published var currentFileURL: URL?
    @Published var isModified: Bool = false {
        didSet {
            updateWindowTitle()
        }
    }
    @Published var windowTitle: String = "Untitled" {
        didSet {
            updateWindowTitle()
        }
    }

    // NSWindowController 역참조 (타이틀 동기화용)
    weak var windowController: DocumentWindowController?

    // 저장된 원본 내용 (수정 여부 판단용)
    private var savedContent: String = ""

    // 윈도우 타이틀 업데이트
    private func updateWindowTitle() {
        windowController?.updateWindowTitle()
    }

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
        windowTitle = TabService.shared.generateNextUntitledTitle()
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.markdown, .plainText]
        panel.allowsMultipleSelection = true  // 여러 파일 선택 허용
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            let urls = panel.urls
            guard !urls.isEmpty else { return }

            // 현재 창이 비어있으면 첫 번째 파일을 현재 창에서 열기
            if currentFileURL == nil && content.isEmpty {
                // 첫 번째 파일 중복 확인
                if TabService.shared.findController(for: urls[0]) == nil {
                    loadFile(from: urls[0])
                }
                // 나머지 파일들은 TabService를 통해 열기
                for url in urls.dropFirst() {
                    TabService.shared.openDocument(url: url)
                }
            } else {
                // 현재 문서가 있으면 모든 파일을 TabService를 통해 열기
                for url in urls {
                    TabService.shared.openDocument(url: url)
                }
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
