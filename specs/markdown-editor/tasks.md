# 구현 계획

## 1. 프로젝트 설정 및 기본 구조

- [ ] 1.1 Xcode 프로젝트 생성
  - SwiftUI 기반 macOS Document App 템플릿으로 프로젝트 생성
  - Bundle Identifier, Team ID 설정
  - 최소 배포 타겟: macOS 13.0
  - _요구사항: 1.1, 11.1_

- [ ] 1.2 프로젝트 디렉토리 구조 설정
  - App/, Views/, ViewModels/, Models/, Services/, Utilities/, Resources/ 디렉토리 생성
  - Info.plist에 문서 타입(.md, .markdown) 등록
  - _요구사항: 8.1, 8.2_

- [ ] 1.3 Swift Package 의존성 추가
  - swift-markdown (Apple) 패키지 추가
  - Package.swift 또는 Xcode SPM을 통해 설정
  - _요구사항: 4.1_

- [ ] 1.4 리소스 파일 추가
  - highlight.min.js, highlight.min.css 추가
  - katex.min.js, katex.min.css 추가
  - mermaid.min.js 추가
  - preview-dark.css, preview-light.css 작성
  - _요구사항: 4.1, 6.1, 6.2_

## 2. 데이터 모델 구현

- [ ] 2.1 MarkdownDocument 모델 구현
  - FileDocument 프로토콜 준수
  - .md, .markdown 파일 타입 지원
  - content, metadata 프로퍼티 구현
  - 파일 읽기/쓰기 로직 구현
  - 단위 테스트 작성
  - _요구사항: 8.1, 8.2, 8.3, 8.4_

- [ ] 2.2 AppState 모델 구현
  - @Observable 매크로 사용
  - editorTheme, previewTheme, previewMode 프로퍼티
  - autoReloadPreview, showLineNumbers, fontSize 설정
  - UserDefaults 저장/로드 로직
  - 단위 테스트 작성
  - _요구사항: 2.1, 2.2, 1.3_

- [ ] 2.3 에러 타입 정의
  - MarkdownEditorError enum 구현
  - fileReadError, fileWriteError, unsupportedFileType 등
  - LocalizedError 프로토콜 준수
  - _요구사항: 5.4_

## 3. 에디터 뷰 구현

- [ ] 3.1 기본 EditorView 구현 (NSViewRepresentable)
  - NSTextView 래핑
  - content 바인딩 구현
  - Coordinator 패턴으로 delegate 처리
  - 기본 폰트 및 스타일 설정
  - _요구사항: 1.1, 1.2_

- [ ] 3.2 LineNumberView 구현
  - NSRulerView 상속
  - 라인 번호 계산 및 렌더링
  - 스크롤 동기화
  - 테마별 색상 적용
  - _요구사항: 1.4_

- [ ] 3.3 SyntaxHighlighter 구현
  - 정규식 기반 패턴 매칭
  - 헤딩, Bold, Italic, 코드, 링크 등 스타일
  - Dark/Light 테마 색상 정의
  - NSAttributedString 적용
  - 단위 테스트 작성
  - _요구사항: 1.5, 2.1_

- [ ] 3.4 EditorView 테마 적용
  - EditorTheme enum 구현
  - 배경색, 텍스트색, 커서색 적용
  - 테마 변경 시 즉시 반영
  - _요구사항: 2.1, 2.3_

## 4. Markdown 프로세서 구현

- [ ] 4.1 기본 MarkdownProcessor 구현
  - swift-markdown 라이브러리 활용
  - Document 파싱 기능
  - 단위 테스트 작성
  - _요구사항: 4.1_

- [ ] 4.2 HTMLVisitor 구현
  - MarkupVisitor 프로토콜 준수
  - 헤딩, 문단, 리스트 변환
  - 테이블, 코드 블록 변환
  - 링크, 이미지, 강조 변환
  - 체크박스 리스트 변환
  - 단위 테스트 작성
  - _요구사항: 4.1, 4.2_

- [ ] 4.3 확장 문법 프로세서 구현
  - 각주 처리 (정규식)
  - 수식 처리 ($...$, $$...$$)
  - 하이라이트 처리 (==...==)
  - 위/아래 첨자 처리
  - 단위 테스트 작성
  - _요구사항: 4.3_

- [ ] 4.4 Mermaid 코드 블록 처리
  - ```mermaid 블록 감지
  - <div class="mermaid"> 태그로 변환
  - 단위 테스트 작성
  - _요구사항: 6.1, 6.2_

- [ ] 4.5 PlantUML 코드 블록 처리
  - ```plantuml 블록 감지
  - PlantUMLService 호출 준비
  - 단위 테스트 작성
  - _요구사항: 6.3, 6.4_

## 5. 성능 최적화 컴포넌트 구현

- [ ] 5.1 Debouncer 구현
  - actor 기반 구현
  - 설정 가능한 지연 시간 (기본 300ms)
  - Task 취소 및 재시작 로직
  - 단위 테스트 작성
  - _요구사항: 7.1, 7.2_

- [ ] 5.2 DiagramCacheManager 구현
  - actor 기반 스레드 안전 구현
  - SHA256 해시 기반 캐시 키
  - 최대 크기 및 만료 시간 설정
  - LRU 방식 캐시 정리
  - 단위 테스트 작성
  - _요구사항: 7.4_

- [ ] 5.3 PlantUMLService 구현
  - PlantUML 인코딩 (Deflate + Base64 변형)
  - 비동기 API 호출 (URLSession)
  - 타임아웃 설정
  - 에러 처리
  - 캐시 통합
  - 단위 테스트 작성
  - _요구사항: 6.3, 6.4, 7.4, 7.6_

- [ ] 5.4 DiagramRenderer 구현
  - Mermaid/PlantUML 통합 렌더링
  - 캐시 확인 우선
  - 에러 결과 HTML 생성
  - 단위 테스트 작성
  - _요구사항: 6.1, 6.3, 6.5_

- [ ] 5.5 IncrementalUpdater 구현
  - 블록 단위 파싱
  - 해시 기반 변경 감지
  - diff 알고리즘 적용
  - insert/remove/update 변경 목록 생성
  - 단위 테스트 작성
  - _요구사항: 7.5_

## 6. 미리보기 뷰 구현

- [ ] 6.1 기본 PreviewView 구현 (NSViewRepresentable)
  - WKWebView 래핑
  - 초기 HTML 템플릿 로드
  - JavaScript 라이브러리 포함
  - _요구사항: 1.1, 1.2_

- [ ] 6.2 PreviewView 테마 적용
  - PreviewTheme enum 구현
  - CSS 파일 동적 로드
  - Mermaid 테마 연동
  - _요구사항: 2.2, 2.3_

- [ ] 6.3 PreviewView 증분 업데이트 적용
  - JavaScript DOM 조작 함수 구현
  - IncrementalUpdater 통합
  - 전체 리로드 최소화
  - _요구사항: 7.5_

- [ ] 6.4 HTMLView 구현
  - HTML 소스 코드 표시 뷰
  - 구문 강조 적용
  - _요구사항: 10.1, 10.3_

- [ ] 6.5 PreviewContainerView 구현
  - Preview/HTML 탭 전환
  - 탭 UI 구현
  - 상태 관리
  - _요구사항: 10.1, 10.2, 10.3_

## 7. 메인 UI 구현

- [ ] 7.1 ContentView 구현
  - HSplitView로 에디터/미리보기 분할
  - 리사이즈 가능한 분할선
  - 최소 너비 설정
  - _요구사항: 1.1_

- [ ] 7.2 EditorViewModel 구현
  - @Observable 매크로 사용
  - content, htmlContent 프로퍼티
  - Debouncer 통합
  - 백그라운드 Markdown 처리
  - _요구사항: 1.2, 1.3, 7.2, 7.3_

- [ ] 7.3 ToolbarView 구현
  - 에디터 테마 선택 드롭다운
  - 미리보기 테마 선택 드롭다운
  - "Automatically reload preview" 체크박스
  - _요구사항: 2.1, 2.2, 1.3_

- [ ] 7.4 포맷팅 버튼 툴바 구현
  - Bold, Italic, Strikethrough 버튼
  - Quote, Code, Link 버튼
  - List 버튼들 (Bulleted, Numbered, Task)
  - Table 버튼
  - Heading 1-5 버튼
  - Export 버튼
  - _요구사항: 3.1_

## 8. 포맷팅 서비스 구현

- [ ] 8.1 FormattingService 기본 구현
  - FormatType enum 정의
  - 텍스트 래핑 로직 (prefix/suffix)
  - 선택 영역 처리
  - 커서 위치 계산
  - _요구사항: 3.2, 3.3_

- [ ] 8.2 개별 포맷팅 기능 구현
  - Bold, Italic, Strikethrough
  - Code (인라인)
  - Link, Image
  - 단위 테스트 작성
  - _요구사항: 3.1, 3.2_

- [ ] 8.3 블록 포맷팅 기능 구현
  - Heading 1-5
  - Quote
  - Bulleted List, Numbered List, Task List
  - Table 템플릿 삽입
  - Horizontal Rule
  - 단위 테스트 작성
  - _요구사항: 3.1, 3.2, 3.3_

- [ ] 8.4 EditorView에 포맷팅 통합
  - 툴바 버튼과 FormattingService 연결
  - 키보드 단축키 지원 (Cmd+B, Cmd+I 등)
  - _요구사항: 3.2_

## 9. 파일 관리 기능 구현

- [ ] 9.1 DocumentGroup 설정
  - MarkdownEditorApp에 DocumentGroup 구성
  - 새 문서, 열기, 저장 기본 기능
  - _요구사항: 8.1, 8.2, 8.3_

- [ ] 9.2 파일 메뉴 커맨드 구현
  - New (Cmd+N)
  - Open (Cmd+O)
  - Save (Cmd+S)
  - Save As (Cmd+Shift+S)
  - _요구사항: 8.1, 8.2, 8.3, 8.4_

- [ ] 9.3 문서 상태 표시
  - 창 제목에 파일명 표시
  - 수정 시 "Edited" 표시
  - 저장되지 않은 변경사항 경고
  - _요구사항: 8.5, 8.6_

## 10. Drag & Drop 구현

- [ ] 10.1 FileDropDelegate 구현
  - DropDelegate 프로토콜 준수
  - .md, .markdown 파일 타입 검증
  - 파일 내용 읽기
  - _요구사항: 5.1, 5.2_

- [ ] 10.2 드롭 영역 시각적 피드백
  - 드래그 진입 시 하이라이트
  - 드롭 가능/불가능 표시
  - _요구사항: 5.1_

- [ ] 10.3 저장 확인 다이얼로그
  - 저장되지 않은 변경사항 확인
  - 저장/취소/무시 옵션
  - _요구사항: 5.3_

- [ ] 10.4 지원하지 않는 파일 처리
  - 에러 메시지 표시
  - Alert 다이얼로그
  - _요구사항: 5.4_

## 11. 내보내기 기능 구현

- [ ] 11.1 ExportService 구현
  - HTML 내보내기 기능
  - 스타일 임베딩
  - 파일 저장 로직
  - 단위 테스트 작성
  - _요구사항: 9.1, 9.2_

- [ ] 11.2 내보내기 UI 구현
  - Export 버튼/메뉴 연결
  - NSSavePanel 표시
  - 파일명 및 위치 선택
  - _요구사항: 9.3_

## 12. 설정 화면 구현

- [ ] 12.1 PreferencesView 구현
  - 일반 설정 탭
  - 에디터 설정 탭
  - 미리보기 설정 탭
  - _요구사항: 2.1, 2.2_

- [ ] 12.2 Settings Scene 등록
  - App에 Settings scene 추가
  - 메뉴 바 "Preferences" 연결
  - _요구사항: 2.1, 2.2_

## 13. 앱 아이콘 설정

- [ ] 13.1 아이콘 생성 스크립트 작성
  - icon.png에서 다양한 크기 생성
  - sips 명령어 사용
  - Contents.json 생성
  - _요구사항: 11.1, 11.2_

- [ ] 13.2 Asset Catalog 설정
  - AppIcon.appiconset 구성
  - 모든 필요 크기 포함
  - Xcode에서 아이콘 확인
  - _요구사항: 11.2, 11.3_

## 14. 빌드 및 배포 스크립트

- [ ] 14.1 빌드 스크립트 작성
  - xcodebuild를 통한 Release 빌드
  - 아카이브 생성
  - _요구사항: 12.1_

- [ ] 14.2 코드 서명 스크립트 작성
  - Developer ID Application 인증서로 서명
  - --deep --options runtime 플래그
  - 서명 검증
  - _요구사항: 13.1_

- [ ] 14.3 DMG 생성 스크립트 작성
  - create-dmg 설치 확인
  - 볼륨 이름, 아이콘, 레이아웃 설정
  - Applications 폴더 링크 추가
  - _요구사항: 12.1, 12.2, 12.3_

- [ ] 14.4 공증 스크립트 작성
  - notarytool submit 명령
  - keychain-profile "notarytool" 사용
  - --wait 플래그로 완료 대기
  - stapler staple로 티켓 첨부
  - 검증
  - _요구사항: 13.2, 13.3, 13.4, 13.5_

- [ ] 14.5 통합 배포 스크립트 작성
  - 빌드 → 서명 → DMG 생성 → 공증 자동화
  - 에러 처리 및 로깅
  - _요구사항: 12.1, 13.1, 13.2, 13.3_

## 15. 테스트 및 검증

- [ ] 15.1 단위 테스트 실행 및 검증
  - 모든 서비스 테스트 통과 확인
  - 코드 커버리지 확인
  - _요구사항: 전체_

- [ ] 15.2 UI 테스트 작성 및 실행
  - 에디터 입력 테스트
  - 포맷팅 버튼 테스트
  - 테마 전환 테스트
  - Drag & Drop 테스트
  - _요구사항: 1, 2, 3, 5_

- [ ] 15.3 성능 테스트
  - 10,000줄 문서 로드 테스트
  - 입력 반응 시간 측정 (16ms 이내)
  - 미리보기 갱신 시간 측정
  - 메모리 사용량 프로파일링
  - _요구사항: 7.1, 7.6_

- [ ] 15.4 다이어그램 렌더링 테스트
  - Mermaid 다이어그램 렌더링 확인
  - PlantUML 다이어그램 렌더링 확인
  - 캐싱 동작 확인
  - 오류 메시지 표시 확인
  - _요구사항: 6.1, 6.2, 6.3, 6.4, 6.5_

- [ ] 15.5 배포 패키지 검증
  - DMG 설치 테스트
  - 공증 상태 확인 (spctl --assess)
  - 다른 Mac에서 설치 테스트
  - _요구사항: 12, 13_
