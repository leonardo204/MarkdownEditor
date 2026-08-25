import SwiftUI
import AppKit

// 마크다운 에디터 뷰
// NSTextView 기반 + 텍스트 선택 포맷팅 지원

// MARK: - 에디터 액션 핸들러
class EditorActionHandler: ObservableObject {
    weak var textView: NSTextView?

    // 선택된 텍스트에 포맷팅 적용
    func applyFormatting(_ action: MarkdownAction) {
        guard let textView = textView,
              let textStorage = textView.textStorage else { return }

        let selectedRange = textView.selectedRange()
        let selectedText = (textStorage.string as NSString).substring(with: selectedRange)

        let replacement: String
        if selectedRange.length > 0 {
            // 선택된 텍스트가 있으면 포맷팅 적용
            replacement = formatText(selectedText, with: action)
        } else {
            // 선택된 텍스트가 없으면 샘플 텍스트 삽입
            replacement = action.insertText
        }

        // 텍스트 교체
        if textView.shouldChangeText(in: selectedRange, replacementString: replacement) {
            textStorage.replaceCharacters(in: selectedRange, with: replacement)
            textView.didChangeText()

            // 커서 위치 조정
            let newPosition = selectedRange.location + replacement.count
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
        }
    }

    private func formatText(_ text: String, with action: MarkdownAction) -> String {
        switch action {
        case .heading(let level):
            return String(repeating: "#", count: level) + " " + text
        case .bold:
            return "**\(text)**"
        case .italic:
            return "*\(text)*"
        case .strikethrough:
            return "~~\(text)~~"
        case .highlight:
            return "==\(text)=="
        case .inlineCode:
            return "`\(text)`"
        case .codeBlock:
            return "```\n\(text)\n```"
        case .link:
            return "[\(text)](url)"
        case .image:
            return "![\(text)](image-url)"
        case .bulletList:
            return text.components(separatedBy: "\n").map { "- \($0)" }.joined(separator: "\n")
        case .numberedList:
            return text.components(separatedBy: "\n").enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        case .taskList:
            return text.components(separatedBy: "\n").map { "- [ ] \($0)" }.joined(separator: "\n")
        case .blockquote:
            return text.components(separatedBy: "\n").map { "> \($0)" }.joined(separator: "\n")
        case .inlineMath:
            return "$\(text)$"
        case .blockMath:
            return "$$\n\(text)\n$$"
        case .mermaid:
            // 선택된 텍스트를 mermaid 코드 블록으로 감싸기
            return "```mermaid\n\(text)\n```"
        case .plantuml:
            // 선택된 텍스트를 plantuml 코드 블록으로 감싸기
            return "```plantuml\n\(text)\n```"
        default:
            return action.insertText
        }
    }
}

// MARK: - SimpleEditorView
struct SimpleEditorView: View {
    @Binding var content: String
    var theme: EditorTheme
    var fontSize: CGFloat
    var showLineNumbers: Bool = true
    var onFileDrop: (([URL]) -> Void)?
    var onImageDrop: ((NSImage, String) -> String?)?
    var onImageFilesDrop: (([URL]) -> Void)?
    var actionHandler: EditorActionHandler?
    var onContentChange: ((String) -> Void)?
    var scrollSyncManager: ScrollSyncManager?
    var findReplaceManager: FindReplaceManager?
    var onCursorLineChange: ((Int) -> Void)?
    var focusMode: Bool = false
    var typewriterMode: Bool = false

    @State private var lineCount: Int = 1
    // 스크롤 오프셋은 스크롤 틱마다 갱신되므로 @State로 두면 에디터 body 전체가 매 틱 재평가된다.
    // 라인번호 뷰만 구독하도록 별도 객체로 분리한다 (소유자는 @State로 보관만 하고 구독하지 않음).
    @State private var scrollState = EditorScrollState()

    var body: some View {
        HStack(spacing: 0) {
            // 라인 번호 영역
            if showLineNumbers {
                LineNumberView(
                    lineCount: lineCount,
                    theme: theme,
                    fontSize: fontSize,
                    scrollState: scrollState
                )
                .frame(width: 44)
            }

            // NSTextView 기반 에디터
            MarkdownNSTextView(
                content: $content,
                theme: theme,
                fontSize: fontSize,
                lineCount: $lineCount,
                scrollState: scrollState,
                onFileDrop: onFileDrop,
                onImageDrop: onImageDrop,
                onImageFilesDrop: onImageFilesDrop,
                actionHandler: actionHandler,
                onContentChange: onContentChange,
                scrollSyncManager: scrollSyncManager,
                findReplaceManager: findReplaceManager,
                onCursorLineChange: onCursorLineChange,
                focusMode: focusMode,
                typewriterMode: typewriterMode
            )
        }
        .background(Color(theme.backgroundColor))
        .onAppear {
            updateLineCount(content)
        }
    }

    private func updateLineCount(_ text: String) {
        lineCount = max(1, text.components(separatedBy: "\n").count)
    }
}

// MARK: - NSTextView 래퍼
struct MarkdownNSTextView: NSViewRepresentable {
    @Binding var content: String
    var theme: EditorTheme
    var fontSize: CGFloat
    @Binding var lineCount: Int
    let scrollState: EditorScrollState
    var onFileDrop: (([URL]) -> Void)?
    var onImageDrop: ((NSImage, String) -> String?)?
    var onImageFilesDrop: (([URL]) -> Void)?
    var actionHandler: EditorActionHandler?
    var onContentChange: ((String) -> Void)?
    var scrollSyncManager: ScrollSyncManager?
    var findReplaceManager: FindReplaceManager?
    var onCursorLineChange: ((Int) -> Void)?
    var focusMode: Bool = false
    var typewriterMode: Bool = false

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = theme.backgroundColor

        // 텍스트 뷰 생성
        let textView = EditorTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = false
        textView.isIncrementalSearchingEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.onFileDrop = onFileDrop
        textView.onImageDrop = onImageDrop
        textView.onImageFilesDrop = onImageFilesDrop
        textView.focusModeEnabled = focusMode
        textView.typewriterModeEnabled = typewriterMode

        // 텍스트 뷰 크기 설정
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 8, height: 8)

        // 텍스트 컨테이너 설정
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        // allowsNonContiguousLayout은 의도적으로 켜지 않는다 (기본값 false 유지).
        // 366KB/8986줄 문서 실측: true로 켜면 documentView 높이가 실제 190406pt 대비
        // 57570~62148pt(약 1/3)로 과소 추정되어 스크롤 가능 범위 자체가 잘리고,
        // 높이가 재추정될 때마다 스크롤 원점이 순간적으로 튀며 스크롤 틱이 40 → 137개로 증폭됐다.
        // ("에디터가 아래로 안 내려간다" 증상의 원인)
        // 오픈 속도 이득보다 스크롤 정확성이 우선이다.

        // 스크롤 뷰에 텍스트 뷰 설정
        scrollView.documentView = textView

        // 초기 내용 및 스타일 설정
        textView.string = content
        context.coordinator.markContentSynced(content)
        context.coordinator.beginFullLayoutPrecompute(for: textView)
        applyTheme(to: textView, coordinator: context.coordinator)

        // 액션 핸들러 연결
        actionHandler?.textView = textView

        // 찾기/바꾸기 매니저에 텍스트뷰 연결
        findReplaceManager?.textView = textView
        context.coordinator.findReplaceManager = findReplaceManager

        // 커서 라인 콜백 연결
        context.coordinator.onCursorLineChange = onCursorLineChange

        // 스크롤 동기화 매니저에 등록
        scrollSyncManager?.editorScrollView = scrollView
        // 프리뷰→에디터 역동기화용 빠른 라인→오프셋 조회 주입 (Coordinator lineStarts 재사용)
        scrollSyncManager?.editorLineToOffset = { [weak coordinator = context.coordinator, weak textView] line in
            guard let coordinator, let textView else { return 0 }
            return coordinator.charOffset(forLine: line, in: textView.string)
        }

        // 라인 번호 뷰가 실제 텍스트 레이아웃을 참조하도록 배선.
        // charIndex(UTF-16) → 0-based 라인 조회는 Coordinator의 lineStarts 이진탐색 재사용.
        context.coordinator.scrollState.textView = textView
        context.coordinator.scrollState.lineNumberProvider = { [weak coordinator = context.coordinator, weak textView] idx in
            guard let coordinator, let textView else { return 0 }
            return coordinator.lineNumber(for: idx, in: textView.string)
        }

        // 스크롤 이벤트 감지
        context.coordinator.scrollSyncManager = scrollSyncManager
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        scrollView.contentView.postsBoundsChangedNotifications = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? EditorTextView else { return }

        // 텍스트 뷰 크기 조정
        // 값이 같아도 대입하면 레이아웃이 무효화되고 boundsDidChange가 재발화해
        // 스크롤 틱이 2배로 늘어난다 → 반드시 달라진 경우에만 대입한다.
        let contentSize = scrollView.contentSize
        if textView.frame.size.width != contentSize.width {
            textView.frame.size.width = contentSize.width
        }
        let newContainerSize = NSSize(width: contentSize.width - 16, height: CGFloat.greatestFiniteMagnitude)
        if textView.textContainer?.containerSize != newContainerSize {
            textView.textContainer?.containerSize = newContainerSize
        }

        // 내용 업데이트 (변경된 경우에만)
        // textView.string은 대형 문서에서 NSTextStorage 브리징 비용이 크고(실측 ~10ms/틱)
        // 여기에 전체 문자열 비교까지 더해진다. Coordinator가 동기화된 콘텐츠를 캐시해
        // O(1) 선판정으로 대체하고, textView는 실제로 밀어넣을 때만 건드린다.
        if !context.coordinator.isUpdating && context.coordinator.needsContentPush(content) {
            let selectedRanges = textView.selectedRanges
            // 무효화는 반드시 대입 "앞"에서 한다.
            // textView.string 대입은 textViewDidChangeSelection을 동기 발화시키는데,
            // 뒤에서 무효화하면 그 콜백이 stale 인덱스로 라인을 계산한다
            // (신·구 길이가 같으면 길이 기반 자동 감지도 걸리지 않는다).
            context.coordinator.invalidateLineIndex()
            textView.string = content
            textView.selectedRanges = selectedRanges
            context.coordinator.markContentSynced(content)
            // 새 문서 → 전체 레이아웃 사전 계산 재시작
            context.coordinator.beginFullLayoutPrecompute(for: textView)
            // string 대입은 textStorage를 교체해 폰트/색 속성을 초기화한다.
            // 캐시를 비워 바로 아래 applyTheme가 강제로 재적용하게 한다
            // (안 그러면 2번째 파일 로드부터 기본 폰트로 회귀한다).
            context.coordinator.lastAppliedFont = nil
            context.coordinator.lastAppliedTextColor = nil
        }

        // 테마 업데이트
        applyTheme(to: textView, coordinator: context.coordinator)
        scrollView.backgroundColor = theme.backgroundColor

        // 드롭/이미지 핸들러 업데이트
        textView.onFileDrop = onFileDrop
        textView.onImageDrop = onImageDrop
        textView.onImageFilesDrop = onImageFilesDrop
        textView.focusModeEnabled = focusMode
        textView.typewriterModeEnabled = typewriterMode

        // 액션 핸들러 업데이트
        actionHandler?.textView = textView

        // 콘텐츠 변경 콜백 업데이트
        context.coordinator.onContentChange = onContentChange
        context.coordinator.onCursorLineChange = onCursorLineChange

        // 찾기/바꾸기 매니저 업데이트
        findReplaceManager?.textView = textView
        context.coordinator.findReplaceManager = findReplaceManager
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(content: $content, lineCount: $lineCount, scrollState: scrollState, onContentChange: onContentChange)
    }

    private func applyTheme(to textView: NSTextView, coordinator: Coordinator) {
        textView.backgroundColor = theme.backgroundColor
        textView.insertionPointColor = theme.cursorColor
        textView.selectedTextAttributes = [
            .backgroundColor: theme.selectionColor
        ]

        // font/textColor는 같은 값을 다시 대입해도 전체 텍스트 레이아웃이 무효화된다.
        // updateNSView가 스크롤마다 호출되므로 값이 실제로 바뀐 경우에만 대입한다.
        //
        // 비교 대상으로 textView.font/textColor 게터를 쓰면 안 된다 —
        // 게터는 textStorage 첫 문자의 속성을 반영하므로 포커스 모드가 텍스트를 딤 처리하면
        // 딤 색이 돌아와 가드가 매번 통과하고(성능 이득 소멸),
        // 이어지는 전체 재대입이 포커스 딤을 지워버린다(기능 회귀).
        // 혼합 폰트일 때 font 게터가 nil을 주는 함정도 같은 이유로 회피된다.
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if coordinator.lastAppliedFont != font {
            textView.font = font
            coordinator.lastAppliedFont = font
        }
        if coordinator.lastAppliedTextColor != theme.textColor {
            textView.textColor = theme.textColor
            coordinator.lastAppliedTextColor = theme.textColor
        }
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, NSTextViewDelegate {
        var content: Binding<String>
        var lineCount: Binding<Int>
        let scrollState: EditorScrollState
        var onContentChange: ((String) -> Void)?
        var onCursorLineChange: ((Int) -> Void)?
        var scrollSyncManager: ScrollSyncManager?
        weak var findReplaceManager: FindReplaceManager?
        var isUpdating = false
        private var lastSelectionTime: CFTimeInterval = 0

        // MARK: - 전체 레이아웃 사전 계산
        // 글리프 레이아웃은 지연 생성이라, 미레이아웃 영역으로 점프하면 glyphIndex(for:in:)가
        // 그 지점까지의 레이아웃을 한 번에 수행하며 메인 스레드를 막는다(실측 589~708ms).
        // 프리뷰 스크롤은 에디터를 임의 위치로 점프시키므로 이 경로에 상시 노출된다.
        // → 문서 로드 후 전체 레이아웃을 미리 만들어 메모리에 유지한다.
        //   메인 스레드를 오래 막지 않도록 청크로 나눠 런루프에 양보하며 진행한다.
        private var layoutPrecomputeGeneration = 0

        func beginFullLayoutPrecompute(for textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }
            let total = (textView.string as NSString).length
            guard total > 0 else { return }

            layoutPrecomputeGeneration += 1
            let generation = layoutPrecomputeGeneration
            let started = CACurrentMediaTime()
            // 청크가 크면 청크당 히치가 커진다(40k자 기준 실측 ~139ms).
            // 작게 잡아 청크당 수십 ms 이내로 유지한다.
            let chunkSize = 8_000
            var location = 0

            func step() {
                // 문서가 바뀌었으면 중단
                guard generation == self.layoutPrecomputeGeneration else { return }
                guard location < total else {
                    let ms = (CACurrentMediaTime() - started) * 1000
                    DebugLogger.shared.log("[Layout] 사전 계산 완료 chars:\(total) \(String(format: "%.0f", ms))ms")
                    return
                }
                let length = min(chunkSize, total - location)
                layoutManager.ensureLayout(forCharacterRange: NSRange(location: location, length: length))
                location += length
                // 런루프에 양보 — 사용자 입력을 막지 않는다
                DispatchQueue.main.async(execute: step)
            }
            // 첫 화면 표시를 방해하지 않도록 다음 런루프 턴부터 시작
            DispatchQueue.main.async(execute: step)
            _ = textContainer
        }

        // MARK: - 콘텐츠 동기화 캐시
        // textView와 동기화된 것으로 간주하는 콘텐츠와 그 UTF-16 길이.
        // 에디터에서 나간 변경(textDidChange)이 이 값을 갱신하므로, 같은 값이
        // SwiftUI를 거쳐 되돌아와도 재대입하지 않는다.
        // 외부 주입(파일 로드 등)은 값이 다르므로 정상적으로 대입된다.
        private var syncedContent: String = ""
        private var syncedUTF16Length: Int = 0

        func markContentSynced(_ text: String) {
            syncedContent = text
            // NSTextView에서 온 문자열은 브릿지 객체라 utf8.count가 O(n)일 수 있다.
            // 길이 선판정에 쓸 값을 여기서 한 번만 계산해 캐시한다.
            syncedUTF16Length = (text as NSString).length
        }

        /// textView에 content를 다시 밀어넣어야 하는지 판정한다.
        /// 길이가 다르면 즉시 결정되고, 같을 때만 == 비교로 확정한다
        /// (동일 스토리지를 공유하면 포인터 비교로 O(1)).
        func needsContentPush(_ candidate: String) -> Bool {
            if (candidate as NSString).length != syncedUTF16Length { return true }
            return candidate != syncedContent
        }

        // 마지막으로 적용한 폰트/텍스트 색 (applyTheme의 재대입 가드용).
        // textView 게터는 포커스 모드 딤 등 런타임 속성 변경에 오염되므로 별도로 캐시한다.
        var lastAppliedFont: NSFont?
        var lastAppliedTextColor: NSColor?

        // MARK: - 라인 인덱스 캐시
        // 스크롤 틱마다 substring + components(separatedBy:)로 O(n) 스캔을 하면
        // 문서 하단으로 갈수록 비용이 커진다(실측 3.5ms/틱).
        // 라인 시작 오프셋 배열을 텍스트 변경 시에만 재구축하고 조회는 이진 탐색으로 처리한다.
        private var lineStarts: [Int] = [0]
        private var indexedLength: Int = -1

        /// 텍스트가 바뀌었음을 알려 다음 조회 시 인덱스를 재구축하게 한다.
        func invalidateLineIndex() {
            indexedLength = -1
        }

        /// UTF-16 오프셋 → 0-based 라인 번호
        func lineNumber(for utf16Offset: Int, in text: String) -> Int {
            let ns = text as NSString
            rebuildLineIndexIfNeeded(ns)

            let target = max(0, min(utf16Offset, ns.length))
            // lineStarts는 오름차순 → target 이하인 마지막 원소의 인덱스가 라인 번호
            var low = 0
            var high = lineStarts.count - 1
            var result = 0
            while low <= high {
                let mid = (low + high) / 2
                if lineStarts[mid] <= target {
                    result = mid
                    low = mid + 1
                } else {
                    high = mid - 1
                }
            }
            return result
        }

        /// 0-based 라인 번호 → 라인 시작 UTF-16 오프셋 (lineStarts 캐시 재사용).
        /// 프리뷰→에디터 역동기화가 매 틱 O(n) 스캔을 피하도록 이진탐색 인덱스를 재활용한다.
        func charOffset(forLine line: Int, in text: String) -> Int {
            let ns = text as NSString
            rebuildLineIndexIfNeeded(ns)
            if line <= 0 { return 0 }
            if line >= lineStarts.count { return ns.length }
            return lineStarts[line]
        }

        private func rebuildLineIndexIfNeeded(_ ns: NSString) {
            // invalidateLineIndex()가 -1로 만들거나, 외부 경로로 길이가 달라진 경우 재구축
            guard ns.length != indexedLength else { return }

            var starts: [Int] = [0]
            var searchStart = 0
            while searchStart < ns.length {
                // .literal: 정준 동등성 비교 경로를 피한다 (키 입력마다 도는 경로)
                let found = ns.range(of: "\n",
                                     options: .literal,
                                     range: NSRange(location: searchStart, length: ns.length - searchStart))
                if found.location == NSNotFound { break }
                let next = found.location + found.length
                starts.append(next)
                searchStart = next
            }
            lineStarts = starts
            indexedLength = ns.length
        }

        init(content: Binding<String>, lineCount: Binding<Int>, scrollState: EditorScrollState, onContentChange: ((String) -> Void)?) {
            self.content = content
            self.lineCount = lineCount
            self.scrollState = scrollState
            self.onContentChange = onContentChange
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        // 커서 이동 시 현재 라인 번호 계산 및 포커스/타자기 모드 처리
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? EditorTextView else { return }

            // 에디터에서 커서 이동 발생 → 검색 대상 자동 선택용으로 에디터를 활성으로 표시
            findReplaceManager?.markEditorActive()

            // 현재 라인 번호 계산
            let cursorPosition = textView.selectedRange().location
            let currentLine = lineNumber(for: cursorPosition, in: textView.string)  // 0-based
            lastSelectionTime = CACurrentMediaTime()
            DebugLogger.shared.log("[Outline] textViewDidChangeSelection: cursorPos:\(cursorPosition), line:\(currentLine), lastSelectionTime:\(lastSelectionTime)")
            onCursorLineChange?(currentLine)

            // 포커스 모드 / 타자기 모드
            if textView.focusModeEnabled {
                textView.applyFocusMode()
            }
            if textView.typewriterModeEnabled {
                textView.centerCurrentLine()
            }
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating,
                  let textView = notification.object as? NSTextView else { return }

            isUpdating = true
            let newText = textView.string
            // 에디터발 변경 → 동기화 기준값 갱신
            // (이 값이 SwiftUI를 거쳐 되돌아와도 updateNSView가 재대입하지 않는다)
            markContentSynced(newText)
            content.wrappedValue = newText
            // 텍스트가 바뀌었으므로 라인 인덱스를 무효화하고, 재구축 결과로 라인 수를 구한다
            invalidateLineIndex()
            lineCount.wrappedValue = max(1, lineNumber(for: (newText as NSString).length, in: newText) + 1)

            // 콘텐츠 변경 콜백 호출
            onContentChange?(newText)

            isUpdating = false
        }

        // 프로그램적 스크롤이 멎은 뒤 1회만 가시 라인을 갱신하기 위한 디바운스
        private var deferredVisibleLineWork: DispatchWorkItem?

        private func scheduleDeferredVisibleLineUpdate(from notification: Notification) {
            deferredVisibleLineWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.updateVisibleLine(from: notification)
            }
            deferredVisibleLineWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
        }

        private func updateVisibleLine(from notification: Notification) {
            guard let clipView = notification.object as? NSClipView,
                  let textView = clipView.documentView as? NSTextView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            let visibleRect = clipView.documentVisibleRect
            let topPoint = NSPoint(x: 0, y: visibleRect.origin.y + textView.textContainerInset.height)
            let glyphIndex = layoutManager.glyphIndex(for: topPoint, in: textContainer)
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            onCursorLineChange?(lineNumber(for: charIndex, in: textView.string))
        }

        @objc func scrollViewDidScroll(_ notification: Notification) {
            // 라인 번호 스크롤 동기화
            if let clipView = notification.object as? NSClipView {
                scrollState.offset = clipView.bounds.origin.y
            }

            scrollSyncManager?.editorDidScroll()

            // 커서 이동 직후(아웃라인 클릭 등)에는 스크롤 기반 업데이트 억제
            // textViewDidChangeSelection이 이미 정확한 커서 라인을 보고했으므로
            // scrollViewDidScroll이 화면 상단 라인으로 덮어쓰는 것을 방지
            let now = CACurrentMediaTime()
            let elapsed = now - lastSelectionTime
            if elapsed < 0.3 {
                DebugLogger.shared.log("[Outline] scrollViewDidScroll SUPPRESSED by selection (elapsed:\(String(format: "%.3f", elapsed))s < 0.3s)")
                return
            }

            // 아웃라인 클릭 후 프리뷰 smooth scroll 동안 에디터 스크롤 기반 라인 업데이트 억제 (1초)
            if let outlineTime = scrollSyncManager?.lastOutlineClickTime, now - outlineTime < 1.0 {
                DebugLogger.shared.log("[Outline] scrollViewDidScroll SUPPRESSED by outlineClick (elapsed:\(String(format: "%.3f", now - outlineTime))s < 1.0s)")
                return
            }

            // 프리뷰가 유발한 프로그램적 스크롤 중에는 무거운 작업(글리프 조회 → 라인 계산)을
            // 매 알림마다 하지 않고, 스크롤이 멎은 뒤 1회만 수행한다.
            // 아웃라인 하이라이트는 조금 늦어도 무방하다.
            if scrollSyncManager?.isProgrammaticScrollActive == true {
                scheduleDeferredVisibleLineUpdate(from: notification)
                return
            }

            // 스크롤 시 보이는 첫 줄 기준으로 아웃라인 업데이트
            guard let clipView = notification.object as? NSClipView,
                  let textView = clipView.documentView as? NSTextView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            let visibleRect = clipView.documentVisibleRect
            let topPoint = NSPoint(x: 0, y: visibleRect.origin.y + textView.textContainerInset.height)
            let glyphIndex = layoutManager.glyphIndex(for: topPoint, in: textContainer)
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

            let visibleLine = lineNumber(for: charIndex, in: textView.string)
            DebugLogger.shared.log("[Outline] scrollViewDidScroll → visibleLine:\(visibleLine) (elapsed:\(String(format: "%.3f", elapsed))s)")
            onCursorLineChange?(visibleLine)

            // VSCode식: 최상단 가시 라인을 프리뷰에 보간 전달 (60fps 쓰로틀은 매니저가 담당)
            scrollSyncManager?.syncPreviewToEditorLine(visibleLine)
        }
    }
}

// MARK: - 에디터 텍스트 뷰 (드래그 앤 드롭 지원)
class EditorTextView: NSTextView {
    var onFileDrop: (([URL]) -> Void)?
    var onImageDrop: ((NSImage, String) -> String?)?  // clipboard image, suggested name -> saved relative path
    var onImageFilesDrop: (([URL]) -> Void)?  // existing image files drop (no save needed)
    var focusModeEnabled: Bool = false {
        didSet {
            if focusModeEnabled {
                applyFocusMode()
            } else {
                removeFocusMode()
            }
        }
    }
    var typewriterModeEnabled: Bool = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .png, .tiff])
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        registerForDraggedTypes([.fileURL, .png, .tiff])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .png, .tiff])
    }

    func applyFocusMode() {
        guard let textStorage = textStorage, let _ = layoutManager else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)

        // Find the current paragraph range
        // selectedRange는 UTF-16 오프셋이므로 상한도 UTF-16 길이로 맞춘다
        // (string.count는 Character 수라 한글 문서에서 범위가 어긋난다)
        let nsString = string as NSString
        let cursorLocation = min(selectedRange().location, nsString.length)
        let paragraphRange = nsString.paragraphRange(for: NSRange(location: cursorLocation, length: 0))

        // Dim all text
        textStorage.addAttribute(.foregroundColor, value: (textColor ?? .white).withAlphaComponent(0.3), range: fullRange)

        // Highlight current paragraph
        if let color = textColor {
            textStorage.addAttribute(.foregroundColor, value: color, range: paragraphRange)
        }
    }

    private func removeFocusMode() {
        guard let textStorage = textStorage else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        if let color = textColor {
            textStorage.addAttribute(.foregroundColor, value: color, range: fullRange)
        }
    }

    func centerCurrentLine() {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer,
              let scrollView = enclosingScrollView else { return }

        let cursorRange = selectedRange()
        // 절대 좌표로 스크롤하기 전에 선행 구간 레이아웃을 확정한다.
        // (연속 레이아웃에서는 대개 이미 확정돼 즉시 반환되는 방어적 호출)
        layoutManager.ensureLayout(forCharacterRange: NSRange(location: 0, length: cursorRange.location))
        let glyphRange = layoutManager.glyphRange(forCharacterRange: cursorRange, actualCharacterRange: nil)
        let lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        let visibleHeight = scrollView.contentView.bounds.height
        let targetY = lineRect.midY - visibleHeight / 2 + textContainerInset.height
        let maxY = frame.height - visibleHeight
        let clampedY = max(0, min(targetY, maxY))

        scrollView.contentView.setBoundsOrigin(NSPoint(x: 0, y: clampedY))
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Cmd+V: 이미지 붙여넣기 우선 처리
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
            let pasteboard = NSPasteboard.general
            if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) {
                paste(nil)
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        // Escape: 찾기 패널 닫기
        if event.keyCode == 53 {
            NotificationCenter.default.post(name: NSNotification.Name("CloseFindPanel"), object: nil)
            return
        }
        // Tab 키 처리 (스페이스 4개로 변환)
        if event.keyCode == 48 {
            insertText("    ", replacementRange: selectedRange())
            return
        }
        super.keyDown(with: event)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        // 이미지 파일 드롭
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            let imageExts = ["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "tiff"]
            let textExts = ["md", "markdown", "txt", "text"]
            let allExts = imageExts + textExts
            if urls.contains(where: { allExts.contains($0.pathExtension.lowercased()) }) {
                return .copy
            }
        }
        // 클립보드 이미지
        if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) {
            return .copy
        }
        return super.draggingEntered(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            // 텍스트 파일 드롭
            let textExtensions = ["md", "markdown", "txt", "text"]
            let textURLs = urls.filter { textExtensions.contains($0.pathExtension.lowercased()) }
            if !textURLs.isEmpty {
                onFileDrop?(textURLs)
                return true
            }

            // 이미지 파일 드롭 (이미 디스크에 존재하는 파일 → 저장 불필요, 바로 삽입)
            let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "tiff"]
            let imageURLs = urls.filter { imageExtensions.contains($0.pathExtension.lowercased()) }
            if !imageURLs.isEmpty {
                onImageFilesDrop?(imageURLs)
                return true
            }
        }

        // 클립보드 이미지 (스크린샷 붙여넣기 등)
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage], let image = images.first {
            let timestamp = Int(Date().timeIntervalSince1970)
            let name = "pasted-image-\(timestamp).png"
            if let relativePath = onImageDrop?(image, name) {
                let markdown = "![pasted image](\(relativePath))"
                insertText(markdown, replacementRange: selectedRange())
            }
            return true
        }

        return super.performDragOperation(sender)
    }

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general

        // 클립보드에 이미지가 있는 경우
        if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil),
           let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first {
            let timestamp = Int(Date().timeIntervalSince1970)
            let name = "pasted-image-\(timestamp).png"
            if let relativePath = onImageDrop?(image, name) {
                let markdown = "![pasted image](\(relativePath))"
                insertText(markdown, replacementRange: selectedRange())
                return
            }
        }

        // 기본 붙여넣기
        super.paste(sender)
    }
}

// MARK: - 라인 번호 뷰 (NSView 기반 — 보이는 라인만 그려서 성능 최적화)
// 에디터 스크롤 오프셋 전용 상태.
// 스크롤 틱마다 갱신되므로, 이걸 구독하는 뷰를 라인번호 뷰 하나로 제한해
// 에디터 body 전체가 매 틱 재평가되는 것을 막는다.
class EditorScrollState: ObservableObject {
    @Published var offset: CGFloat = 0
    // 라인 번호를 실제 텍스트 레이아웃에 맞춰 그리기 위한 비발행 참조.
    // (@Published가 아니므로 대입해도 SwiftUI 갱신을 유발하지 않는다)
    weak var textView: NSTextView?
    var lineNumberProvider: ((Int) -> Int)?  // charIndex(UTF-16) → 0-based 라인
}

struct LineNumberView: NSViewRepresentable {
    let lineCount: Int
    let theme: EditorTheme
    let fontSize: CGFloat
    // 스크롤 오프셋 변경을 실제로 구독하는 유일한 뷰
    @ObservedObject var scrollState: EditorScrollState

    func makeNSView(context: Context) -> LineNumberNSView {
        let view = LineNumberNSView()
        view.update(lineCount: lineCount, theme: theme, fontSize: fontSize,
                    scrollOffset: scrollState.offset,
                    textView: scrollState.textView,
                    provider: scrollState.lineNumberProvider)
        return view
    }

    func updateNSView(_ view: LineNumberNSView, context: Context) {
        view.update(lineCount: lineCount, theme: theme, fontSize: fontSize,
                    scrollOffset: scrollState.offset,
                    textView: scrollState.textView,
                    provider: scrollState.lineNumberProvider)
        view.needsDisplay = true
    }
}

class LineNumberNSView: NSView {
    private var lineCount: Int = 1
    private var scrollOffset: CGFloat = 0
    private var editorFontSize: CGFloat = 14
    private var textColor: NSColor = .secondaryLabelColor
    private var bgColor: NSColor = .windowBackgroundColor
    private var borderColor: NSColor = .separatorColor
    private weak var textView: NSTextView?
    private var lineNumberProvider: ((Int) -> Int)?

    override var isFlipped: Bool { true }

    func update(lineCount: Int, theme: EditorTheme, fontSize: CGFloat, scrollOffset: CGFloat,
                textView: NSTextView?, provider: ((Int) -> Int)?) {
        self.lineCount = lineCount
        self.editorFontSize = fontSize
        self.scrollOffset = scrollOffset
        self.textColor = theme.lineNumberColor
        self.bgColor = theme.gutterBackgroundColor
        self.borderColor = theme.gutterBorderColor
        self.textView = textView
        self.lineNumberProvider = provider
    }

    override func draw(_ dirtyRect: NSRect) {
        // 배경
        bgColor.setFill()
        bounds.fill()

        let font = NSFont.monospacedSystemFont(ofSize: editorFontSize * 0.85, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]

        // 실제 텍스트 레이아웃 기반 렌더링.
        // 줄바꿈(soft wrap)·헤딩·이미지로 행 높이가 제각각이므로 고정 높이 가정은 못 쓴다.
        // 가시 영역에 걸친 라인 프래그먼트만 순회하고, 각 소스 라인의 첫 프래그먼트에만 번호를 그린다.
        if let textView, let provider = lineNumberProvider,
           let layoutManager = textView.layoutManager,
           let textContainer = textView.textContainer {
            drawWithLayout(layoutManager: layoutManager, textContainer: textContainer,
                           textView: textView, provider: provider, attrs: attrs)
        } else {
            // 폴백: 레이아웃 배선 전이면 고정 높이 근사로 그린다.
            drawFixedHeight(attrs: attrs)
        }

        // 우측 보더
        borderColor.setFill()
        NSRect(x: bounds.width - 1, y: 0, width: 1, height: bounds.height).fill()
    }

    private func drawWithLayout(layoutManager: NSLayoutManager, textContainer: NSTextContainer,
                                textView: NSTextView, provider: @escaping (Int) -> Int,
                                attrs: [NSAttributedString.Key: Any]) {
        let inset = textView.textContainerInset.height

        // 가시 영역을 컨테이너 좌표로 변환 (textView y = container y + inset)
        let visibleContainerRect = NSRect(x: 0,
                                          y: scrollOffset - inset,
                                          width: textContainer.size.width,
                                          height: bounds.height)
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleContainerRect, in: textContainer)

        var lastDrawnLine = -1
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, fragmentGlyphRange, _ in
            let charIndex = layoutManager.characterIndexForGlyph(at: fragmentGlyphRange.location)
            let line = provider(charIndex)  // 0-based
            // 접힌(soft-wrap) 줄은 같은 소스 라인 → 첫 프래그먼트에만 번호를 그린다
            if line == lastDrawnLine { return }
            lastDrawnLine = line

            // 컨테이너 좌표 → 거터(flipped) 좌표
            let yInGutter = usedRect.minY + inset - self.scrollOffset
            let str = "\(line + 1)"
            let size = (str as NSString).size(withAttributes: attrs)
            let x = self.bounds.width - size.width - 9
            (str as NSString).draw(at: NSPoint(x: x, y: yInGutter + (usedRect.height - size.height) / 2),
                                   withAttributes: attrs)
        }

        // 마지막 빈 줄(문서가 개행으로 끝나는 경우 등)의 번호도 그린다
        if layoutManager.extraLineFragmentTextContainer != nil {
            let rect = layoutManager.extraLineFragmentUsedRect
            let yInGutter = rect.minY + inset - scrollOffset
            if yInGutter + rect.height >= 0 && yInGutter <= bounds.height {
                let line = provider((textView.string as NSString).length)
                if line != lastDrawnLine {
                    let str = "\(line + 1)"
                    let size = (str as NSString).size(withAttributes: attrs)
                    let x = bounds.width - size.width - 9
                    (str as NSString).draw(at: NSPoint(x: x, y: yInGutter + (rect.height - size.height) / 2),
                                           withAttributes: attrs)
                }
            }
        }
    }

    private func drawFixedHeight(attrs: [NSAttributedString.Key: Any]) {
        let lineHeight = editorFontSize * 1.35
        let topPadding: CGFloat = 8
        let firstLine = max(1, Int((scrollOffset - topPadding) / lineHeight) + 1)
        let lastLine = min(lineCount, Int((scrollOffset + bounds.height - topPadding) / lineHeight) + 2)

        for line in firstLine...max(firstLine, lastLine) {
            let y = topPadding + CGFloat(line - 1) * lineHeight - scrollOffset
            let str = "\(line)"
            let size = (str as NSString).size(withAttributes: attrs)
            let x = bounds.width - size.width - 9
            (str as NSString).draw(at: NSPoint(x: x, y: y + (lineHeight - size.height) / 2), withAttributes: attrs)
        }
    }
}
