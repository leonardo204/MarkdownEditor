import SwiftUI
import UniformTypeIdentifiers

// Markdown 문서 모델
// FileDocument 프로토콜을 준수하여 파일 읽기/쓰기 지원

struct MarkdownDocument: FileDocument {
    // 지원하는 파일 타입
    static var readableContentTypes: [UTType] { [.markdown, .plainText] }
    static var writableContentTypes: [UTType] { [.markdown] }

    // 문서 내용
    var content: String

    // 문서 메타데이터
    var metadata: DocumentMetadata

    // 기본 생성자
    init(content: String = "") {
        self.content = content
        self.metadata = DocumentMetadata()
    }

    // 파일에서 읽기
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.content = string
        self.metadata = DocumentMetadata()
    }

    // 파일로 쓰기
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = content.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}

// 문서 메타데이터
struct DocumentMetadata {
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    var wordCount: Int {
        let words = content.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }

    var characterCount: Int {
        return content.count
    }

    private var content: String = ""

    mutating func update(with content: String) {
        self.content = content
        self.modifiedAt = Date()
    }
}

// UTType 확장 - Markdown 타입 정의
extension UTType {
    static var markdown: UTType {
        UTType(importedAs: "net.daringfireball.markdown")
    }
}
