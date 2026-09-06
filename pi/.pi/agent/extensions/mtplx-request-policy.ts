const mtplxModelID = "mtplx-qwen38-27b-optimized-speed";
const mtplxUncapped = true;
const mtplxPiInjectedDefaultMaxTokens = 16384;

export default function (pi: any) {
  pi.on("before_provider_headers", (event: any, ctx: any) => {
    const headers = event?.headers;
    if (!headers || typeof headers !== "object") return;
    const client = Object.entries(headers).find(
      ([key]) => key.toLowerCase() === "x-mtplx-client",
    )?.[1];
    if (client !== "pi") return;
    event.headers["x-mtplx-session-id"] = String(
      ctx.sessionManager.getSessionId(),
    );
  });

  pi.on("before_provider_request", (event: any) => {
    const payload = event?.payload;
    if (!mtplxUncapped || !payload || typeof payload !== "object") return;
    if (payload.model !== mtplxModelID) return;
    // Strip only Pi's serialized default ceiling; an explicit user cap (any
    // other value) is honored end to end.
    const request = { ...payload };
    let changed = false;
    if (request.max_tokens === mtplxPiInjectedDefaultMaxTokens) {
      delete request.max_tokens;
      changed = true;
    }
    if (request.max_completion_tokens === mtplxPiInjectedDefaultMaxTokens) {
      delete request.max_completion_tokens;
      changed = true;
    }
    if (!changed) return;
    return request;
  });
}
