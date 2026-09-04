/**
 * 방문 기록 한 건을 대시보드(ai.zerolive.co.kr)로 보낸다.
 *
 * 응답을 이미 돌려준 뒤 waitUntil로 뒤에서 보내므로 사용자가 기다리는 시간에는 영향이 없다.
 * 실패해도 조용히 넘어간다 — 기록이 서비스를 멈추게 두면 안 된다.
 * 사람인지 크롤러인지 가리는 일은 대시보드가 한다(여기서는 값만 넘긴다).
 */
const HIT_URL = "https://ai.zerolive.co.kr/v1/hit";

export interface HitEnv {
	TRAFFIC_TOKEN?: string;
}

export function sendHit(
	site: string,
	request: Request,
	response: Response,
	env: HitEnv,
	ctx: ExecutionContext,
	startedAt: number,
): void {
	if (!env.TRAFFIC_TOKEN) return;
	try {
		const url = new URL(request.url);
		const cf = (request as unknown as { cf?: Record<string, unknown> }).cf;
		const str = (v: unknown) => (typeof v === "string" ? v : "");
		ctx.waitUntil(
			fetch(HIT_URL, {
				method: "POST",
				headers: {
					"Content-Type": "application/json",
					Authorization: `Bearer ${env.TRAFFIC_TOKEN}`,
				},
				body: JSON.stringify({
					site,
					path: url.pathname,
					status: response.status,
					ms: Date.now() - startedAt,
					ua: request.headers.get("User-Agent") || "",
					ref: request.headers.get("Referer") || "",
					country: str(cf?.country) || request.headers.get("CF-IPCountry") || "",
					region: str(cf?.region),
					city: str(cf?.city),
					ip: request.headers.get("CF-Connecting-IP") || "",
					method: request.method,
				}),
			}).catch(() => undefined),
		);
	} catch {
		/* 기록 실패는 무시한다 */
	}
}
