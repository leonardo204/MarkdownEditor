import Foundation
import AppKit

// MARK: - 디렉토리 접근 Bookmark 관리자
// App Sandbox 환경에서 이미지 파일 접근을 위해
// security-scoped bookmark를 저장/복원합니다.

class DirectoryBookmarkManager {
    static let shared = DirectoryBookmarkManager()

    private let bookmarkKey = "directoryBookmarks"

    private init() {}

    // 저장된 bookmark에서 디렉토리 접근 시작 (상위 디렉토리 북마크도 탐색)
    func startAccessing(directoryOf fileURL: URL) -> Bool {
        guard let bookmarks = UserDefaults.standard.dictionary(forKey: bookmarkKey) else { return false }

        let dirPath = fileURL.deletingLastPathComponent().path
        // 정확한 경로 → 상위 디렉토리 순으로 매칭되는 북마크 탐색
        var searchPath = dirPath
        while searchPath != "/" && !searchPath.isEmpty {
            if let data = bookmarks[searchPath] as? Data {
                return resolveAndAccess(data, forDirectory: searchPath)
            }
            searchPath = (searchPath as NSString).deletingLastPathComponent
        }
        return false
    }

    private func resolveAndAccess(_ data: Data, forDirectory dirPath: String) -> Bool {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data,
                                  options: .withSecurityScope,
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale) else { return false }

        if isStale {
            if let newData = try? url.bookmarkData(options: .withSecurityScope,
                                                    includingResourceValuesForKeys: nil,
                                                    relativeTo: nil) {
                saveBookmark(newData, forDirectory: dirPath)
            }
        }

        return url.startAccessingSecurityScopedResource()
    }

    // NSOpenPanel로 디렉토리 접근 요청 + bookmark 저장
    func requestAccess(forDirectoryOf fileURL: URL, completion: @escaping (Bool) -> Void) {
        let dirURL = fileURL.deletingLastPathComponent()

        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.message = "이미지를 표시하려면 문서가 있는 폴더에 대한 접근을 허용해 주세요."
            panel.prompt = "허용"
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
                    _ = selectedURL.startAccessingSecurityScopedResource()
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
