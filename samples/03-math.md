# 감량 속도와 필요 열량

몸무게 기록에서 하루 목표 열량을 뽑는 계산을 정리했습니다.

## 기초 대사량

성별에 따라 계수만 다릅니다. $W$ 는 몸무게(kg), $H$ 는 키(cm), $A$ 는 나이입니다.

$$
\mathrm{BMR} = 10W + 6.25H - 5A +
\begin{cases}
  +5 & \text{남성} \\
  -161 & \text{여성}
\end{cases}
$$

여기에 활동 계수 $k$ 를 곱하면 하루 소비 열량이 됩니다.

$$
\mathrm{TDEE} = k \cdot \mathrm{BMR}, \qquad k \in [1.2,\ 1.9]
$$

## 목표 열량

일주일에 $\Delta$ kg 을 줄이려면, 지방 1kg 을 약 7,700 kcal 로 보고 이렇게 잡습니다.

$$
E_{\text{목표}} = \mathrm{TDEE} - \frac{7700 \cdot \Delta}{7}
$$

안전 범위는 $\Delta \le 0.75$ 이고, 어떤 경우에도 $E_{\text{목표}} \ge 1200$ 을 지킵니다.

## 흔들리는 기록 다듬기

몸무게는 하루하루 출렁이므로 지수 이동 평균으로 눌러줍니다.

$$
S_t = \alpha x_t + (1-\alpha) S_{t-1}, \qquad \alpha = \frac{2}{n+1}
$$

$n = 7$ 이면 $\alpha \approx 0.25$ 입니다. 아래는 실제로 적용한 값입니다.

| 날짜 | 측정값 (kg) | 평활값 (kg) | 전날 대비 |
|---|---:|---:|---:|
| 09-01 | 72.4 | 72.40 | — |
| 09-02 | 73.1 | 72.58 | +0.18 |
| 09-03 | 72.0 | 72.43 | −0.15 |
| 09-04 | 71.8 | 72.27 | −0.16 |
| 09-05 | 72.6 | 72.35 | +0.08 |
| 09-06 | 71.5 | 72.14 | −0.21 |
| 09-07 | 71.3 | 71.93 | −0.21 |

측정값은 1.8kg 을 오르내렸지만 평활값은 0.47kg 만 움직였습니다.

## 계산 코드

```python
def smooth(values, window=7):
    alpha = 2 / (window + 1)
    result, prev = [], values[0]
    for v in values:
        prev = alpha * v + (1 - alpha) * prev
        result.append(round(prev, 2))
    return result


def target_calories(tdee, weekly_loss_kg):
    deficit = 7700 * weekly_loss_kg / 7
    return max(1200, round(tdee - deficit))
```

```sql
SELECT
    date,
    weight_kg,
    AVG(weight_kg) OVER (
        ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS avg_7d
FROM weight_log
WHERE user_id = 42
ORDER BY date DESC
LIMIT 30;
```

## 확인할 것

- [x] 성별·나이 계수 검증
- [x] 최저 열량 하한 적용
- [ ] 근육량을 따로 받는 경우의 보정식
- [ ] 정체기 판정 기준 정하기

> 참고: 이 값은 일반적인 추정치입니다. 질환이 있거나 약을 드시는 경우에는 전문의와 상의하세요.
