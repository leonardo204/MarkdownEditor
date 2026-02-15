import SwiftUI
import UniformTypeIdentifiers
import WebKit

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

    private let recentFilesKey = "RecentFiles"
    private let maxRecentFiles = 10

    // 환경설정 윈도우 관리
    private var settingsWindowController: NSWindowController?

    // 최근 파일 메뉴
    private var recentFilesMenu: NSMenu?

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

        // 최근 파일
        let recentMenuItem = NSMenuItem(title: "최근 파일 열기", action: nil, keyEquivalent: "")
        let recentMenu = NSMenu(title: "최근 파일 열기")
        recentMenuItem.submenu = recentMenu
        fileMenu.addItem(recentMenuItem)
        self.recentFilesMenu = recentMenu
        rebuildRecentFilesMenu()

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

        fileMenu.addItem(NSMenuItem.separator())

        let exportHTMLItem = NSMenuItem(title: "HTML로 내보내기...", action: #selector(exportAsHTML(_:)), keyEquivalent: "")
        exportHTMLItem.target = self
        fileMenu.addItem(exportHTMLItem)

        let exportPDFItem = NSMenuItem(title: "PDF로 내보내기...", action: #selector(exportAsPDF(_:)), keyEquivalent: "")
        exportPDFItem.target = self
        fileMenu.addItem(exportPDFItem)

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
        editMenu.addItem(NSMenuItem.separator())

        // 찾기 & 바꾸기 (커스텀 찾기 패널 — Notification 기반)
        editMenu.addItem(NSMenuItem(title: "찾기...", action: #selector(showFindPanel(_:)), keyEquivalent: "f"))

        let replaceItem = NSMenuItem(title: "찾기 및 바꾸기...", action: #selector(showReplacePanel(_:)), keyEquivalent: "f")
        replaceItem.keyEquivalentModifierMask = [.command, .option]
        editMenu.addItem(replaceItem)

        editMenu.addItem(NSMenuItem(title: "다음 찾기", action: #selector(findNext(_:)), keyEquivalent: "g"))

        let findPrevItem = NSMenuItem(title: "이전 찾기", action: #selector(findPrevious(_:)), keyEquivalent: "G")
        findPrevItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(findPrevItem)

        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Format 메뉴
        let formatMenuItem = NSMenuItem()
        let formatMenu = NSMenu(title: "Format")

        let boldItem = NSMenuItem(title: "볼드", action: #selector(formatBold(_:)), keyEquivalent: "b")
        boldItem.target = self
        formatMenu.addItem(boldItem)

        let italicItem = NSMenuItem(title: "이탤릭", action: #selector(formatItalic(_:)), keyEquivalent: "i")
        italicItem.target = self
        formatMenu.addItem(italicItem)

        let linkItem = NSMenuItem(title: "링크 삽입", action: #selector(formatLink(_:)), keyEquivalent: "k")
        linkItem.target = self
        formatMenu.addItem(linkItem)

        formatMenu.addItem(NSMenuItem.separator())

        let codeItem = NSMenuItem(title: "인라인 코드", action: #selector(formatInlineCode(_:)), keyEquivalent: "e")
        codeItem.target = self
        formatMenu.addItem(codeItem)

        let strikeItem = NSMenuItem(title: "취소선", action: #selector(formatStrikethrough(_:)), keyEquivalent: "d")
        strikeItem.keyEquivalentModifierMask = [.command, .shift]
        strikeItem.target = self
        formatMenu.addItem(strikeItem)

        formatMenuItem.submenu = formatMenu
        mainMenu.addItem(formatMenuItem)

        // View 메뉴
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        let toggleTabBarItem = NSMenuItem(title: "탭 바 표시/숨기기", action: #selector(toggleTabBar(_:)), keyEquivalent: "")
        toggleTabBarItem.target = self
        viewMenu.addItem(toggleTabBarItem)
        let toggleOutlineItem = NSMenuItem(title: "아웃라인 표시/숨기기", action: #selector(toggleOutline(_:)), keyEquivalent: "O")
        toggleOutlineItem.keyEquivalentModifierMask = [.command, .shift]
        toggleOutlineItem.target = self
        viewMenu.addItem(toggleOutlineItem)
        let toggleTypewriterItem = NSMenuItem(title: "Typewriter Mode", action: #selector(toggleTypewriterMode(_:)), keyEquivalent: "T")
        toggleTypewriterItem.keyEquivalentModifierMask = [.command, .shift]
        toggleTypewriterItem.target = self
        viewMenu.addItem(toggleTypewriterItem)
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
        windowMenu.addItem(NSMenuItem.separator())

        // Cmd+1~9: 탭 전환
        for i in 1...9 {
            let tabItem = NSMenuItem(title: "탭 \(i)로 이동", action: #selector(selectTabByNumber(_:)), keyEquivalent: "\(i)")
            tabItem.tag = i
            tabItem.target = self
            windowMenu.addItem(tabItem)
        }

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

    @objc func toggleOutline(_ sender: Any?) {
        NotificationCenter.default.post(name: NSNotification.Name("ToggleOutline"), object: nil)
    }

    @objc func toggleTypewriterMode(_ sender: Any?) {
        NotificationCenter.default.post(name: NSNotification.Name("ToggleTypewriterMode"), object: nil)
    }

    @objc func selectTabByNumber(_ sender: NSMenuItem) {
        guard let keyWindow = NSApp.keyWindow,
              let tabbedWindows = keyWindow.tabbedWindows,
              !tabbedWindows.isEmpty else { return }

        let index = sender.tag - 1  // tag는 1-based, 배열은 0-based
        guard index >= 0 && index < tabbedWindows.count else { return }

        tabbedWindows[index].makeKeyAndOrderFront(nil)
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

    // MARK: - 내보내기

    @objc func exportAsHTML(_ sender: Any?) {
        guard let keyWindow = NSApp.keyWindow,
              let controller = TabService.shared.managedWindows.first(where: { $0.window === keyWindow })?.controller else { return }

        let dm = controller.documentManager
        let processor = MarkdownProcessor()
        let htmlBody = processor.convertToHTML(dm.content)

        // CSS 로드
        let cssContent: String
        if let cssURL = Bundle.main.url(forResource: "preview", withExtension: "css"),
           let css = try? String(contentsOf: cssURL, encoding: .utf8) {
            cssContent = css
        } else {
            cssContent = "body { font-family: -apple-system, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }"
        }

        let fullHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <title>\(dm.windowTitle)</title>
        <style>\(cssContent)</style>
        </head>
        <body>
        \(htmlBody)
        </body>
        </html>
        """

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = (dm.currentFileURL?.deletingPathExtension().lastPathComponent ?? dm.windowTitle) + ".html"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try fullHTML.write(to: url, atomically: true, encoding: .utf8)
                DebugLogger.shared.log("Exported HTML: \(url.lastPathComponent)")
            } catch {
                let alert = NSAlert()
                alert.messageText = "HTML 내보내기 실패"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }

    @objc func exportAsPDF(_ sender: Any?) {
        guard let keyWindow = NSApp.keyWindow,
              let controller = TabService.shared.managedWindows.first(where: { $0.window === keyWindow })?.controller else { return }

        let dm = controller.documentManager
        let processor = MarkdownProcessor()
        let htmlBody = processor.convertToHTML(dm.content)

        // CSS 로드
        let cssContent: String
        if let cssURL = Bundle.main.url(forResource: "preview", withExtension: "css"),
           let css = try? String(contentsOf: cssURL, encoding: .utf8) {
            cssContent = css
        } else {
            cssContent = "body { font-family: -apple-system, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }"
        }

        let fullHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        \(cssContent)
        @media print { body { margin: 0; } }
        </style>
        </head>
        <body>
        \(htmlBody)
        </body>
        </html>
        """

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = (dm.currentFileURL?.deletingPathExtension().lastPathComponent ?? dm.windowTitle) + ".pdf"

        if panel.runModal() == .OK, let url = panel.url {
            // WKWebView를 사용하여 PDF 렌더링
            let config = WKWebViewConfiguration()
            let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 595, height: 842), configuration: config)
            webView.loadHTMLString(fullHTML, baseURL: Bundle.main.resourceURL)

            // 렌더링 완료 대기를 위한 타이머
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let pdfConfig = WKPDFConfiguration()
                pdfConfig.rect = CGRect(x: 0, y: 0, width: 595.28, height: 841.89) // A4

                webView.createPDF(configuration: pdfConfig) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let data):
                            do {
                                try data.write(to: url)
                                DebugLogger.shared.log("Exported PDF: \(url.lastPathComponent)")
                            } catch {
                                let alert = NSAlert()
                                alert.messageText = "PDF 저장 실패"
                                alert.informativeText = error.localizedDescription
                                alert.runModal()
                            }
                        case .failure(let error):
                            let alert = NSAlert()
                            alert.messageText = "PDF 생성 실패"
                            alert.informativeText = error.localizedDescription
                            alert.runModal()
                        }
                    }
                }
            }
        }
    }

    // MARK: - 찾기/바꾸기 액션 (커스텀 패널)

    @objc func showFindPanel(_ sender: Any?) {
        NotificationCenter.default.post(name: NSNotification.Name("ShowFindPanel"), object: nil)
    }

    @objc func showReplacePanel(_ sender: Any?) {
        NotificationCenter.default.post(name: NSNotification.Name("ShowReplacePanel"), object: nil)
    }

    @objc func findNext(_ sender: Any?) {
        NotificationCenter.default.post(name: NSNotification.Name("FindNext"), object: nil)
    }

    @objc func findPrevious(_ sender: Any?) {
        NotificationCenter.default.post(name: NSNotification.Name("FindPrevious"), object: nil)
    }

    // MARK: - 서식 단축키 액션

    private func currentEditorTextView() -> NSTextView? {
        guard let keyWindow = NSApp.keyWindow else { return nil }
        // First responder가 NSTextView이면 직접 사용
        if let textView = keyWindow.firstResponder as? NSTextView {
            return textView
        }
        return nil
    }

    private func wrapSelectionWith(prefix: String, suffix: String) {
        guard let textView = currentEditorTextView() else { return }
        let selectedRange = textView.selectedRange()
        let text = (textView.string as NSString)

        if selectedRange.length > 0 {
            // 선택된 텍스트를 래핑
            let selected = text.substring(with: selectedRange)
            let replacement = "\(prefix)\(selected)\(suffix)"
            textView.insertText(replacement, replacementRange: selectedRange)
            // 래핑된 텍스트를 다시 선택
            textView.setSelectedRange(NSRange(location: selectedRange.location + prefix.count, length: selectedRange.length))
        } else {
            // 선택 없으면 커서 위치에 삽입하고 커서를 사이에 배치
            let replacement = "\(prefix)\(suffix)"
            textView.insertText(replacement, replacementRange: selectedRange)
            textView.setSelectedRange(NSRange(location: selectedRange.location + prefix.count, length: 0))
        }
    }

    @objc func formatBold(_ sender: Any?) {
        wrapSelectionWith(prefix: "**", suffix: "**")
    }

    @objc func formatItalic(_ sender: Any?) {
        wrapSelectionWith(prefix: "*", suffix: "*")
    }

    @objc func formatLink(_ sender: Any?) {
        guard let textView = currentEditorTextView() else { return }
        let selectedRange = textView.selectedRange()
        let text = (textView.string as NSString)

        if selectedRange.length > 0 {
            let selected = text.substring(with: selectedRange)
            let replacement = "[\(selected)](url)"
            textView.insertText(replacement, replacementRange: selectedRange)
            // "url" 부분을 선택
            let urlStart = selectedRange.location + selected.count + 3
            textView.setSelectedRange(NSRange(location: urlStart, length: 3))
        } else {
            let replacement = "[](url)"
            textView.insertText(replacement, replacementRange: selectedRange)
            textView.setSelectedRange(NSRange(location: selectedRange.location + 1, length: 0))
        }
    }

    @objc func formatInlineCode(_ sender: Any?) {
        wrapSelectionWith(prefix: "`", suffix: "`")
    }

    @objc func formatStrikethrough(_ sender: Any?) {
        wrapSelectionWith(prefix: "~~", suffix: "~~")
    }

    // MARK: - 최근 파일 관리

    func addToRecentFiles(_ url: URL) {
        var recentFiles = UserDefaults.standard.stringArray(forKey: recentFilesKey) ?? []
        let path = url.path

        // 이미 있으면 맨 앞으로 이동
        recentFiles.removeAll { $0 == path }
        recentFiles.insert(path, at: 0)

        // 최대 개수 제한
        if recentFiles.count > maxRecentFiles {
            recentFiles = Array(recentFiles.prefix(maxRecentFiles))
        }

        UserDefaults.standard.set(recentFiles, forKey: recentFilesKey)
        rebuildRecentFilesMenu()
    }

    private func rebuildRecentFilesMenu() {
        guard let menu = recentFilesMenu else { return }
        menu.removeAllItems()

        let recentFiles = UserDefaults.standard.stringArray(forKey: recentFilesKey) ?? []

        if recentFiles.isEmpty {
            let emptyItem = NSMenuItem(title: "최근 파일 없음", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for path in recentFiles {
                let url = URL(fileURLWithPath: path)
                let item = NSMenuItem(title: url.lastPathComponent, action: #selector(openRecentFile(_:)), keyEquivalent: "")
                item.representedObject = url
                item.target = self
                menu.addItem(item)
            }
            menu.addItem(NSMenuItem.separator())
            let clearItem = NSMenuItem(title: "최근 기록 지우기", action: #selector(clearRecentFiles(_:)), keyEquivalent: "")
            clearItem.target = self
            menu.addItem(clearItem)
        }
    }

    @objc func openRecentFile(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            TabService.shared.openDocument(url: url)
        } else {
            // 파일이 없으면 목록에서 제거
            var recentFiles = UserDefaults.standard.stringArray(forKey: recentFilesKey) ?? []
            recentFiles.removeAll { $0 == url.path }
            UserDefaults.standard.set(recentFiles, forKey: recentFilesKey)
            rebuildRecentFilesMenu()

            let alert = NSAlert()
            alert.messageText = "파일을 찾을 수 없습니다"
            alert.informativeText = "\"\(url.lastPathComponent)\" 파일이 이동되었거나 삭제되었습니다."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "확인")
            alert.runModal()
        }
    }

    @objc func clearRecentFiles(_ sender: Any?) {
        UserDefaults.standard.removeObject(forKey: recentFilesKey)
        rebuildRecentFilesMenu()
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
             #selector(toggleTabBar(_:)),
             #selector(exportAsHTML(_:)),
             #selector(exportAsPDF(_:)):
            // 저장/닫기/내보내기는 윈도우가 있을 때만 활성화
            return NSApp.keyWindow != nil
        case #selector(selectTabByNumber(_:)):
            // 탭 전환은 해당 탭이 존재할 때만 활성화
            guard let keyWindow = NSApp.keyWindow,
                  let tabbedWindows = keyWindow.tabbedWindows else { return false }
            return menuItem.tag <= tabbedWindows.count
        default:
            return true
        }
    }

    // NSWindow에서 DocumentManager 찾기 (TabService 사용)
    private func findDocumentManager(in window: NSWindow) -> DocumentManager? {
        return TabService.shared.managedWindows.first(where: { $0.window === window })?.controller.documentManager
    }

    // MARK: - 앱 비활성화 시 파일 감시 일시정지 / 활성화 시 재개
    func applicationDidBecomeActive(_ notification: Notification) {
        // 모든 열린 문서의 파일 변경 확인
        for managed in TabService.shared.managedWindows {
            managed.controller.documentManager.checkForExternalChanges()
        }
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

    // 파일 변경 감지
    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private var lastKnownModDate: Date?

    // 자동 저장
    private var autoSaveTimer: Timer?
    private let autoSaveDelay: TimeInterval = 3.0

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
            startFileMonitoring()
            // 최근 파일 목록에 추가
            (NSApp.delegate as? AppDelegate)?.addToRecentFiles(url)
        } catch {
            print("파일 읽기 오류: \(error)")
        }
    }

    // MARK: - 파일 변경 감지

    func startFileMonitoring() {
        stopFileMonitoring()
        guard let url = currentFileURL else { return }

        // 현재 수정일 기록
        lastKnownModDate = fileModificationDate(for: url)

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.checkForExternalChanges()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        fileMonitorSource = source
    }

    func stopFileMonitoring() {
        autoSaveTimer?.invalidate()
        fileMonitorSource?.cancel()
        fileMonitorSource = nil
    }

    func checkForExternalChanges() {
        guard let url = currentFileURL else { return }

        let currentModDate = fileModificationDate(for: url)
        guard let lastDate = lastKnownModDate, let newDate = currentModDate,
              newDate > lastDate else { return }

        lastKnownModDate = newDate

        do {
            let externalContent = try String(contentsOf: url, encoding: .utf8)

            // 내용이 실제로 다른 경우만 처리
            guard externalContent != savedContent else { return }

            if isModified {
                // 사용자가 수정 중이면 알림
                DispatchQueue.main.async { [weak self] in
                    self?.showExternalChangeAlert(newContent: externalContent)
                }
            } else {
                // 수정 중이 아니면 자동 반영
                DispatchQueue.main.async { [weak self] in
                    self?.content = externalContent
                    self?.savedContent = externalContent
                    self?.isModified = false
                }
            }
        } catch {
            DebugLogger.shared.log("외부 변경 감지 실패: \(error)")
        }
    }

    private func showExternalChangeAlert(newContent: String) {
        let alert = NSAlert()
        alert.messageText = "파일이 외부에서 변경되었습니다"
        alert.informativeText = "\"\(windowTitle)\" 파일이 다른 프로그램에서 수정되었습니다. 다시 불러오시겠습니까?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "다시 불러오기")
        alert.addButton(withTitle: "무시")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            content = newContent
            savedContent = newContent
            isModified = false
        }
    }

    private func fileModificationDate(for url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }

    // MARK: - 자동 저장

    private func scheduleAutoSave() {
        autoSaveTimer?.invalidate()
        guard currentFileURL != nil, isModified else { return }
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveDelay, repeats: false) { [weak self] _ in
            self?.performAutoSave()
        }
    }

    private func performAutoSave() {
        guard isModified, let url = currentFileURL else { return }
        saveFile(to: url)
        DebugLogger.shared.log("Auto-saved: \(url.lastPathComponent)")
    }

    deinit {
        autoSaveTimer?.invalidate()
        stopFileMonitoring()
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
            // 저장 후 수정일 갱신 (자체 저장을 외부 변경으로 감지하지 않도록)
            lastKnownModDate = fileModificationDate(for: url)
        } catch {
            print("파일 저장 오류: \(error)")
        }
    }

    func updateContent(_ newContent: String) {
        content = newContent
        // savedContent와 비교하여 수정 여부 판단
        isModified = (content != savedContent)
        if isModified {
            scheduleAutoSave()
        }
    }
}
