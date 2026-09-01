import Foundation
import AppKit

// MARK: - 디렉토리 접근 Bookmark 관리자
// App Sandbox 환경에서 이미지 파일 접근을 위해
// security-scoped bookmark를 저장/복원합니다.

class DirectoryBookmarkManager {
    static let shared = DirectoryBookmarkManager()

    private let bookmarkKey = "directoryBookmarks"

    // 이미 보안 스코프를 개시한 디렉토리 → resolve된 URL.
    // startAccessingSecurityScopedResource는 호출마다 참조를 증가시키므로
    // 문서를 열 때마다 재호출하면 균형이 깨진다. 키 존재 여부로 중복 개시를 막는다.
    // URL을 보관하는 이유: 향후 stopAccessingSecurityScopedResource를 호출하려면
    // 개시할 때 쓴 것과 동일한 URL 인스턴스가 필요하기 때문이다.
    //
    // 스레드 계약: 메인 스레드에서만 접근한다 (진입부에서 dispatchPrecondition으로 강제).
    private var accessedDirectories: [String: URL] = [:]

    private init() {}

    // 저장된 bookmark에서 디렉토리 접근 시작 (상위 디렉토리 북마크도 탐색)
    // 중복 호출에 안전하다 — 같은 디렉토리는 최초 1회만 실제로 개시한다.
    @discardableResult
    func startAccessing(directoryOf fileURL: URL) -> Bool {
        dispatchPrecondition(condition: .onQueue(.main))

        guard let bookmarks = UserDefaults.standard.dictionary(forKey: bookmarkKey) else { return false }

        let dirPath = fileURL.deletingLastPathComponent().path
        // 정확한 경로 → 상위 디렉토리 순으로 매칭되는 북마크 탐색
        var searchPath = dirPath
        while searchPath != "/" && !searchPath.isEmpty {
            if let data = bookmarks[searchPath] as? Data {
                if accessedDirectories[searchPath] != nil { return true }
                guard let url = resolveAndAccess(data, forDirectory: searchPath) else { return false }
                accessedDirectories[searchPath] = url
                return true
            }
            searchPath = (searchPath as NSString).deletingLastPathComponent
        }
        return false
    }

    /// 북마크를 resolve하고 보안 스코프를 개시한다.
    /// - Returns: 개시에 성공한 URL (실패 시 nil)
    private func resolveAndAccess(_ data: Data, forDirectory dirPath: String) -> URL? {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data,
                                  options: .withSecurityScope,
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale) else { return nil }

        if isStale {
            if let newData = try? url.bookmarkData(options: .withSecurityScope,
                                                    includingResourceValuesForKeys: nil,
                                                    relativeTo: nil) {
                saveBookmark(newData, forDirectory: dirPath)
            }
        }

        return url.startAccessingSecurityScopedResource() ? url : nil
    }

    // NSOpenPanel로 디렉토리 접근 요청 + bookmark 저장
    func requestAccess(forDirectoryOf fileURL: URL, completion: @escaping (Bool) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))

        let dirURL = fileURL.deletingLastPathComponent()

        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.message = L("panel.directory_access.message")
            panel.prompt = L("button.allow")
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.directoryURL = dirURL

            if panel.runModal() == .OK, let selectedURL = panel.url {
                if let bookmarkData = try? selectedURL.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ) {
                    self.saveBookmark(bookmarkData, forDirectory: selectedURL.path)
                    // 개시 성공을 기록해야 이후 startAccessing이 중복 클레임을 만들지 않는다
                    if selectedURL.startAccessingSecurityScopedResource() {
                        self.accessedDirectories[selectedURL.path] = selectedURL
                    }
                    completion(true)
                    return
                }
            }
            completion(false)
        }
    }

    private func saveBookmark(_ data: Data, forDirectory path: String) {
        var bookmarks = UserDefaults.standard.dictionary(forKey: bookmarkKey) ?? [:]
        bookmarks[path] = data
        UserDefaults.standard.set(bookmarks, forKey: bookmarkKey)
    }
}
