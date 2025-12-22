import XCTest
@testable import MarkdownEditor

final class MarkdownEditorTests: XCTestCase {

    // MARK: - MarkdownDocument Tests

    func testDocumentInitialization() {
        // 빈 문서 생성
        let document = MarkdownDocument()
        XCTAssertEqual(document.content, "")
    }

    func testDocumentWithContent() {
        // 내용이 있는 문서 생성
        let content = "# Hello World"
        let document = MarkdownDocument(content: content)
        XCTAssertEqual(document.content, content)
    }

    func testDocumentMetadata() {
        // 메타데이터 테스트
        let document = MarkdownDocument(content: "Hello World")
        XCTAssertNotNil(document.metadata.createdAt)
    }
}
