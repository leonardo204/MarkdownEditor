# 스크롤 동기화 설계 노트

> 편집 화면과 미리보기가 **같은 줄**을 보게 만드는 것이 목표입니다.
> 퍼센트가 아니라 소스 줄을 기준으로 맞춥니다.

문서가 길어질수록 "지금 쓰고 있는 문단이 오른쪽 어디쯤인지" 감이 사라집니다.
비율로 맞추면 그림 하나만 들어가도 두 화면이 어긋나기 시작합니다.
그래서 줄 번호를 기준점으로 삼았습니다.

## 무엇을 고쳤나

- 미리보기 블록마다 원본 줄 번호를 심어 둡니다
- 편집 화면이 움직이면 그 줄을 감싸는 두 지점 사이를 계산해 미리보기를 옮깁니다
- 반대 방향도 같은 방식으로 되돌립니다
- 스크롤 막대를 손으로 끌 때도 동일하게 동작합니다

### 처리 순서

1. 미리보기를 그릴 때 블록 요소에 줄 번호를 붙인다
2. 그 목록을 한 번만 모아 배열로 들고 있는다
3. 스크롤이 생기면 이진 탐색으로 앞뒤 지점을 찾는다
4. 두 지점 사이를 비례로 나눠 최종 위치를 정한다

## 남은 일

- [x] 휠과 트랙패드 동기화
- [x] 스크롤 막대 드래그 동기화
- [x] 이미지가 늦게 불러와질 때 위치 어긋남 방지
- [ ] 표가 가로로 넘칠 때 위치 보정
- [ ] 접힌 코드 블록 처리

## 핵심 코드

두 지점 사이를 나누는 부분입니다.

```swift
func targetY(for line: Double) -> CGFloat {
    let base = Int(floor(line))
    let ratio = CGFloat(line - Double(base))

    let top = y(ofLine: base)
    let next = y(ofLine: base + 1)

    return top + ratio * (next - top)
}
```

미리보기 쪽은 브라우저에서 같은 계산을 합니다.

```javascript
function scrollToLine(line) {
  const i = anchorIndex(line);
  const prev = anchors[i];
  const next = anchors[i + 1];
  if (!next) return window.scrollTo(0, docTop(prev.el));

  const p = (line - prev.line) / (next.line - prev.line);
  window.scrollTo(0, docTop(prev.el) + p * (docTop(next.el) - docTop(prev.el)));
}
```

## 측정 결과

| 문서 크기 | 이전 방식 | 줄 기준 방식 | 한 번 처리에 걸린 시간 |
|---|---|---|---|
| 200줄 | 어긋남 없음 | 어긋남 없음 | 0.4 ms |
| 2,000줄 | 최대 12줄 | 1줄 이내 | 0.6 ms |
| 12,000줄 | 최대 90줄 | 1줄 이내 | 0.9 ms |
| 그림 40장 | 최대 3화면 | 1줄 이내 | 1.1 ms |

`0.016초`마다 한 번만 계산하도록 묶어서, 빠르게 굴려도 밀리지 않습니다.

## 참고

- [CommonMark 규격](https://spec.commonmark.org/)
- [Apple TextKit 문서](https://developer.apple.com/documentation/uikit/textkit)
- 관련 논의: `#124`, `#131`

---

*마지막 수정: 2026년 9월*
