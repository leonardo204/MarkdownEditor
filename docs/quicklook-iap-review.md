# Markdown Quick Look + In-App Purchase 기능 검토

## 1. Quick Look Extension (QLPreviewExtension)

### 기술적 구현 방식

macOS에서 Quick Look 확장은 **QLPreviewingController** 프로토콜을 준수하는 별도 App Extension Target으로 구현합니다.

```
MarkdownEditor/
├── MarkdownEditor/          ← 기존 앱
├── MarkdownQuickLook/       ← 새 타겟 (Quick Look Preview Extension)
│   ├── PreviewViewController.swift   # QLPreviewingController
│   ├── Info.plist
│   └── MarkdownQuickLook.entitlements
└── Shared/                  ← 공유 코드
    ├── MarkdownProcessor.swift   # AST → HTML (기존 코드 재사용)
    └── PreviewHTML.swift         # HTML 템플릿 + CSS
```

### 재사용 가능한 기존 자산

| 자산 | 파일 | 재사용도 |
|------|------|---------|
| MD → HTML 변환 | `MarkdownProcessor.swift` | **100%** - AST 파서 그대로 공유 가능 |
| Mermaid 렌더링 | `PreviewView.swift` 내 JS | **90%** - HTML 템플릿 추출하여 공유 |
| CSS 테마 | `preview-light.css`, `preview-dark.css` + 내장 CSS | **100%** |
| UTType 선언 | `Info.plist`의 `net.daringfireball.markdown` | **100%** |

현재 `MarkdownProcessor`가 Mermaid(`<div class="mermaid">`)를 이미 처리하고, `PreviewView`에서 mermaid.js CDN 로딩도 구현되어 있어 핵심 렌더링 로직은 거의 준비되어 있음.

### 핵심 제약사항 및 도전

| 항목 | 상세 | 난이도 |
|------|------|--------|
| **네트워크 접근** | Quick Look Extension은 **샌드박스** 환경. Mermaid.js CDN 로딩에 `com.apple.security.network.client` 필요 → Extension에도 추가해야 함 | 낮음 |
| **Mermaid.js 번들링** | CDN 의존 대신 **로컬 번들**에 mermaid.min.js를 포함하는 것이 안정적 (오프라인 지원, 로딩 속도). 현재 앱도 CDN 방식이므로 앱/Extension 모두 개선 필요 | 중간 |
| **렌더링 시간** | Quick Look은 빠른 응답을 기대함. 대용량 Mermaid 다이어그램은 JS 실행 시간이 길 수 있음 → `WKWebView` + 타임아웃 처리 필요 | 중간 |
| **WKWebView 사용** | Quick Look Extension에서 `WKWebView`를 사용할 수 있으나, macOS 12+ 필요. 현재 앱이 이미 `WKWebView` 기반이므로 문제 없음 | 낮음 |
| **앱과 Extension 간 코드 공유** | Swift Package 또는 Framework Target으로 `MarkdownProcessor` + HTML 템플릿을 분리해야 함 | 중간 |

### Quick Look Extension 핵심 코드 구조 (참고)

```swift
class PreviewViewController: NSViewController, QLPreviewingController {
    func preparePreviewOfFile(at url: URL) async throws {
        let markdown = try String(contentsOf: url, encoding: .utf8)
        let processor = MarkdownProcessor()
        let html = processor.convertToHTML(markdown)
        let fullHTML = wrapWithTemplate(html) // Mermaid.js 포함
        // WKWebView에 로드
    }
}
```

## 2. In-App Purchase (StoreKit 2)

### 구현 방식

| 항목 | 권장 |
|------|------|
| **API** | StoreKit 2 (async/await, macOS 12+) |
| **상품 유형** | Non-Consumable (1회 구매, 영구 사용) |
| **상품 ID** | 예: `com.zerolive.MarkdownEditor.premium.quicklook` |
| **구매 상태 저장** | `Transaction.currentEntitlements` (StoreKit 자체 관리, UserDefaults 불필요) |

### 구현 범위

```swift
// 1. StoreManager (구매 관리)
class StoreManager: ObservableObject {
    @Published var isPremium: Bool = false
    func checkEntitlements() async { ... }
    func purchase(_ product: Product) async throws { ... }
}

// 2. SettingsView에 "Premium" 탭 추가
// 3. Quick Look Extension에서 구매 상태 확인 → App Group 공유
```

### IAP + Quick Look 연동의 핵심 과제

| 과제 | 설명 | 해결 방법 |
|------|------|----------|
| **구매 상태 공유** | 앱 본체에서 구매 → Extension에서 확인 필요 | **App Group** (`group.com.zerolive.MarkdownEditor`) + `UserDefaults(suiteName:)` |
| **Extension에서 StoreKit 직접 호출 불가** | Extension은 StoreKit Transaction 직접 검증 어려움 | 앱 본체가 구매 시 App Group의 UserDefaults에 플래그 저장, Extension이 읽음 |
| **미구매 시 동작** | Quick Look Extension이 설치되면 무조건 동작하는 구조 | 미구매 시: 기본 텍스트 프리뷰 또는 "Premium 기능입니다" 워터마크/안내 표시 |

## 3. 종합 판단

### 가능 여부: 충분히 가능

| 평가 항목 | 결과 |
|-----------|------|
| 기술적 실현 가능성 | **높음** — 핵심 렌더링 로직이 이미 구현됨 |
| 코드 재사용률 | **80%+** — MarkdownProcessor, CSS, HTML 템플릿 |
| App Store 심사 리스크 | **낮음** — Quick Look Extension은 Apple 공식 확장 포인트 |
| IAP 심사 리스크 | **낮음** — Non-Consumable 단일 상품은 심사가 비교적 단순 |

### 필요 작업 목록 (우선순위 순)

1. **코드 분리** — `MarkdownProcessor` + HTML 템플릿을 공유 Framework/SPM 모듈로 추출
2. **Mermaid.js 로컬 번들링** — CDN 의존 제거 (오프라인 Quick Look 지원 필수)
3. **Quick Look Extension 타겟 추가** — `QLPreviewingController` 구현
4. **App Group 설정** — 앱 ↔ Extension 간 구매 상태 공유
5. **StoreKit 2 통합** — `StoreManager`, 구매 UI, Transaction 리스너
6. **Settings에 Premium 탭 추가** — 구매/복원 버튼
7. **미구매 시 Fallback** — 기본 텍스트 미리보기 또는 안내 메시지

### 주의사항

- **Mermaid.js 번들 크기**: mermaid.min.js는 약 2.5MB. Extension에 포함하면 앱 크기 증가
- **KaTeX/PlantUML**: 현재 앱에서 지원하는 수식/PlantUML도 Quick Look에 포함할지 범위 결정 필요 (PlantUML은 외부 서버 kroki.io 의존이라 오프라인 불가)
- **macOS 최소 버전**: StoreKit 2 + QLPreviewExtension 모두 **macOS 12+** 필요
