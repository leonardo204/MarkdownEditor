# 문서 저장 흐름

편집한 내용이 파일로 남기까지 어떤 길을 지나는지 그림으로 정리했습니다.

## 전체 흐름

```mermaid
flowchart TD
    A[키 입력] --> B{3초 동안 조용한가}
    B -- 아니오 --> A
    B -- 예 --> C[자동 저장 시작]
    C --> D{파일 경로가 있나}
    D -- 없음 --> E[저장 위치 묻기]
    D -- 있음 --> F[디스크에 쓰기]
    E --> F
    F --> G[수정한 시각 갱신]
    G --> H[제목의 별표 지우기]
```

## 외부에서 파일이 바뀌었을 때

```mermaid
sequenceDiagram
    participant 외부 as 다른 프로그램
    participant 감시 as 파일 감시
    participant 앱 as 에디터
    participant 사용자 as 사용자

    외부->>감시: 파일 저장
    감시->>앱: 바뀌었다고 알림
    앱->>앱: 수정한 시각 비교
    alt 편집 중이 아님
        앱->>앱: 새 내용으로 바로 교체
    else 편집 중임
        앱->>사용자: 다시 불러올지 물어보기
        사용자-->>앱: 다시 불러오기
        앱->>앱: 새 내용으로 교체
    end
```

## 탭과 창의 관계

```mermaid
flowchart LR
    subgraph 창1[창 1]
        T1[읽어보기.md]
        T2[설계.md]
    end
    subgraph 창2[창 2]
        T3[회의록.md]
    end
    T1 -. 드래그 .-> 창2
    창2 -. 창 합치기 .-> 창1
```

## 미리보기가 그려지는 과정

```plantuml
@startuml
skinparam backgroundColor transparent
actor 사용자
participant "편집 화면" as Editor
participant "변환기" as Parser
participant "미리보기" as Preview

사용자 -> Editor: 글자 입력
Editor -> Editor: 0.3초 기다리기
Editor -> Parser: 마크다운 넘기기
Parser -> Parser: 구문 나무 만들기
Parser -> Preview: HTML + 줄 번호
Preview -> Preview: 그림·수식 그리기
Preview --> 사용자: 화면 갱신
@enduml
```

## 만들면서 정한 것

| 항목 | 정한 값 | 이유 |
|---|---|---|
| 미리보기 갱신 대기 | 0.3초 | 타자 속도보다 느리게 잡아야 화면이 떨리지 않음 |
| 자동 저장 대기 | 3초 | 문단 하나를 끝낼 만한 시간 |
| 동기화 간격 | 0.016초 | 화면 주사율에 맞춤 |
