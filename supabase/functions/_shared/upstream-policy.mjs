// Explicit read-only allowlist. POST does not imply an RPC is safe to replay.
const readRPCs = new Set(['wif_resolve_app_user', 'wif_snapshot']);
export function retryableRead(request, origin) {
    const url = new URL(request.url);
    return url.origin === origin && ((request.method === 'GET' && url.pathname === '/auth/v1/user')
        || (request.method === 'POST' && readRPCs.has(url.pathname.replace('/rest/v1/rpc/', ''))
            && url.pathname.startsWith('/rest/v1/rpc/')));
}

export function temporaryStatus(error, status = error?.status) {
    const code = error?.code ?? '';
    const message = String(error?.message ?? '').toLowerCase();
    if (Number(status) === 504 || Number(status) === 408 || code === '57014'
        || /timeout|timed out|aborterror|timeouterror/.test(message)) return 504;
    if (Number(status) === 429) return 429;
    if (Number(status) >= 500 || code === 'PGRST003' || /^08/.test(code)
        || ['53300', '57P01', '57P02', '57P03'].includes(code)
        || /gateway|fetch failed|fetcherror|failed to fetch|network|connection reset|connection refused|service unavailable/.test(message)) return 503;
    return null;
}

export function authFailureStatus(error) {
    const temporary = temporaryStatus(error);
    if (temporary) return temporary;
    if (['bad_jwt', 'session_not_found', 'user_not_found', 'no_authorization'].includes(error?.code)
        || [401, 403].includes(Number(error?.status))) return 401;
    // An unknown upstream failure is not proof that the user's session expired.
    return 503;
}

export function resilientSupabaseFetch(origin, {fetchImpl = fetch, timeoutMs = 6500,
    delay = ms => new Promise(resolve => setTimeout(resolve, ms)),
    log = entry => console.warn(JSON.stringify(entry))} = {}) {
    return async (input, init) => {
        const original = new Request(input, init);
        const safe = retryableRead(original, origin);
        const path = new URL(original.url).pathname;
        // No query strings, bodies, credentials, account IDs or error messages in logs.
        const stage = path === '/auth/v1/user' ? 'auth_user'
            : path.startsWith('/rest/v1/rpc/wif_') ? path.split('/').at(-1) : 'other_upstream';
        for (let attempt = 1; attempt <= (safe ? 2 : 1); attempt++) {
            const controller = new AbortController();
            const timer = setTimeout(() => controller.abort(), timeoutMs);
            const started = Date.now();
            try {
                const response = await fetchImpl(new Request(original.clone(), {
                    signal: AbortSignal.any([original.signal, controller.signal]),
                }));
                // Bound body reads too: receiving headers alone is not completion.
                const bytes = await response.arrayBuffer();
                const transient = [408, 429, 500, 502, 503, 504].includes(response.status);
                if (transient) log({event: 'upstream_failure', stage, status: response.status,
                    attempt, elapsed_ms: Date.now() - started, request_id: response.headers.get('sb-request-id')});
                if (transient && response.status !== 429 && safe && attempt === 1 && !original.signal.aborted) {
                    clearTimeout(timer);
                    await delay(200 + Math.floor(Math.random() * 100));
                    continue;
                }
                return new Response([204, 205, 304].includes(response.status) ? null : bytes,
                    {status: response.status, statusText: response.statusText, headers: response.headers});
            } catch (error) {
                log({event: 'upstream_failure', stage, status: controller.signal.aborted ? 504 : 503,
                    attempt, elapsed_ms: Date.now() - started});
                if (safe && attempt === 1 && !original.signal.aborted) {
                    clearTimeout(timer);
                    await delay(200 + Math.floor(Math.random() * 100));
                    continue;
                }
                // SDKs may wrap thrown fetch errors; use a fixed non-sensitive message.
                throw new Error(controller.signal.aborted ? 'Upstream request timed out.' : 'Upstream network request failed.');
            } finally { clearTimeout(timer); }
        }
    };
}
