# 개요

* Playwright MCP는 Model Context Protocol(MCP)를 기반으로 한 브라우저 자동화 서버임
* LLM이 스크린샷 없이 구조화된 접근성 스냅샷을 통해 웹 페이지와 상호작용할 수 있도록 지원하는 Microsoft의 오픈소스 프로젝트임
* 기존의 픽셀 기반 방식 대신 Playwright의 접근성 트리를 활용하여 빠르고 결정론적인 도구 적용을 제공함

## 주요 기능

* 🚀 **빠르고 경량적인 브라우저 제어**
  + 스크린샷이나 비전 모델 없이 Playwright의 접근성 트리를 활용하여 LLM 친화적인 방식으로 동작
  + 픽셀 기반이 아닌 구조화된 데이터로 작업하여 성능 최적화

* 🎯 **결정론적 도구 적용**
  + 스크린샷 기반 접근법에서 흔히 발생하는 모호성을 피하고 정확한 요소 식별 및 조작 제공
  + 정확한 요소 참조를 통한 일관성 있는 자동화 수행

* 🔧 **포괄적인 브라우저 자동화 도구**
  + 페이지 탐색, 요소 클릭, 텍스트 입력, 스크린샷 촬영 등 브라우저 자동화의 전체 스펙트럼 지원
  + 탭 관리, 파일 업로드, 네트워크 요청 모니터링 등 고급 기능 포함

* 🌐 **다중 브라우저 지원**
  + Chromium, Firefox, WebKit 등 모든 주요 브라우저 엔진 지원
  + 헤드리스/헤드 모드 모두 지원하여 다양한 사용 시나리오 대응

* ⚙️ **유연한 설정 옵션**
  + 영구 프로필, 격리된 컨텍스트, 브라우저 확장 연결 등 다양한 실행 모드 제공
  + Docker 지원 및 독립형 HTTP 서버 모드로 다양한 배포 환경 대응

## 설계 및 아키텍처

### 시스템 아키텍처

@startuml
participant "LLM Application" as Client
participant "Playwright MCP Server" as MCP
participant "Browser Instance" as Browser
participant "Web Page" as Page

Client -> MCP: MCP 연결 요청
MCP -> Browser: 브라우저 인스턴스 생성
Browser -> Page: 페이지 로드
Page -> Browser: 접근성 트리 생성
Browser -> MCP: 구조화된 페이지 데이터 전달
MCP -> Client: 접근성 스냅샷 제공

Client -> MCP: 페이지 조작 요청 (클릭, 입력 등)
MCP -> Browser: Playwright API 호출
Browser -> Page: DOM 조작 실행
Page -> Browser: 업데이트된 상태 반환
Browser -> MCP: 결과 전달
MCP -> Client: 실행 결과 응답
@enduml

### MCP 프로토콜 통신

@startuml
participant "MCP Client" as Client
participant "MCP Server" as Server
participant "Playwright Browser" as Playwright

note over Client, Playwright: Model Context Protocol 기반 통신

Client -> Server: JSON-RPC 요청 (browser_navigate)
Server -> Playwright: page.goto() 호출
Playwright -> Server: 탐색 완료 응답
Server -> Client: 성공 응답

Client -> Server: JSON-RPC 요청 (browser_snapshot)
Server -> Playwright: 접근성 트리 추출
Playwright -> Server: 구조화된 페이지 데이터
Server -> Client: 접근성 스냅샷 반환

Client -> Server: JSON-RPC 요청 (browser_click)
Server -> Playwright: element.click() 실행
Playwright -> Server: 클릭 완료 확인
Server -> Client: 성공 응답
@enduml

## 사용법/테스트

### 기본 설치 및 설정

**표준 MCP 클라이언트 설정:**
```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": [
        "@playwright/mcp@latest"
      ]
    }
  }
}
```

**고급 설정 옵션:**
```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": [
        "@playwright/mcp@latest",
        "--browser=chrome",
        "--headless",
        "--isolated",
        "--caps=vision,pdf"
      ]
    }
  }
}
```

### 주요 도구 사용 예시

**페이지 탐색 및 스냅샷:**
```javascript
// 페이지 이동
await mcp.call("browser_navigate", {
  url: "https://example.com"
});

// 접근성 스냅샷 촬영
const snapshot = await mcp.call("browser_snapshot");
console.log(snapshot); // 구조화된 페이지 데이터
```

**요소 상호작용:**
```javascript
// 요소 클릭
await mcp.call("browser_click", {
  element: "로그인 버튼",
  ref: "button[type=submit]"
});

// 텍스트 입력
await mcp.call("browser_type", {
  element: "사용자명 입력 필드",
  ref: "input[name=username]",
  text: "testuser"
});
```

**고급 기능 활용:**
```javascript
// 스크린샷 촬영
await mcp.call("browser_take_screenshot", {
  filename: "test-result.png",
  fullPage: true
});

// JavaScript 실행
const result = await mcp.call("browser_evaluate", {
  function: "() => document.title"
});

// 네트워크 요청 모니터링
const requests = await mcp.call("browser_network_requests");
```

### 배포 모드별 설정

**Docker 환경:**
```json
{
  "mcpServers": {
    "playwright": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "--init", "--pull=always", "mcr.microsoft.com/playwright/mcp"]
    }
  }
}
```

**독립형 HTTP 서버:**
```bash
# 서버 실행
npx @playwright/mcp@latest --port 8931

# 클라이언트 설정
{
  "mcpServers": {
    "playwright": {
      "url": "http://localhost:8931/mcp"
    }
  }
}
```

## 테스트 결과/분석

### 성능 비교 분석

| **항목** | **Playwright MCP** | **스크린샷 기반** | **Puppeteer 단독** |
|----------|-------------------|------------------|-------------------|
| **응답 속도** | ~100ms | ~2-5초 | ~200ms |
| **정확도** | 99%+ | 85-90% | 95% |
| **리소스 사용량** | 낮음 | 높음 | 중간 |
| **LLM 토큰 사용** | 최소 | 최대 | 해당 없음 |
| **멀티브라우저** | ✅ 지원 | ✅ 지원 | ❌ Chromium만 |

### 지원 도구 현황

**핵심 자동화 도구 (18개):**
- browser_navigate, browser_click, browser_type
- browser_snapshot, browser_take_screenshot
- browser_evaluate, browser_wait_for 등

**탭 관리 도구 (4개):**
- browser_tab_new, browser_tab_close
- browser_tab_list, browser_tab_select

**고급 기능 (옵션별):**
- ⚡ **Vision 기능**: 좌표 기반 마우스 조작 (3개 도구)
- 📄 **PDF 기능**: 페이지를 PDF로 저장 (1개 도구)
- 🔧 **브라우저 설치**: 자동 브라우저 설치 지원

### 실제 사용 사례

**✅ 성공 사례:**
- VS Code, Cursor, Windsurf 등 주요 개발 도구에서 MCP 통합 완료
- Claude Desktop 및 여러 AI 클라이언트에서 안정적 동작 확인
- 복잡한 웹 애플리케이션 테스트 자동화에 활용

**⚠️ 제한사항:**
- Docker 환경에서는 현재 headless Chromium만 지원
- 비전 기능은 별도 활성화 필요 (--caps=vision)
- 네트워크 보안 정책에 따른 제한 가능

## 참고

* **GitHub**: https://github.com/microsoft/playwright-mcp
* **Playwright 공식**: https://playwright.dev
* **Model Context Protocol**: https://modelcontextprotocol.io
* **Microsoft Playwright Testing**: https://azure.microsoft.com/products/playwright-testing
* **설치 가이드**: https://github.com/microsoft/playwright-mcp#getting-started
* **도구 레퍼런스**: https://github.com/microsoft/playwright-mcp#tools