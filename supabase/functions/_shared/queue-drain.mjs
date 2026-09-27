// One request owns its deadline and concurrency budget; no cross-request mutable state.
export async function settleBatch(tasks) {
    const results = await Promise.allSettled(tasks);
    const failed = results.find(result => result.status === 'rejected');
    if (failed) throw failed.reason;
    return results.map(result => result.value);
}

export function deliveryGate({concurrency = 6, deadline, now = Date.now}) {
    let active = 0;
    const waiting = [];
    return async task => {
        if (active >= concurrency) await new Promise(resolve => waiting.push(resolve));
        else active++;
        try {
            // Unstarted deliveries retain their SQL lease and can be retried safely.
            if (now() >= deadline) return 'deferred';
            return await task();
        } finally {
            const next = waiting.shift();
            if (next) next(); else active--;
        }
    };
}

export async function drainQueues(queues, {deadline, maxRounds = 10, now = Date.now}) {
    // Every kind gets a lane so a busy same-city queue cannot starve invitations.
    const results = await Promise.all(Object.entries(queues).map(async ([name, batch]) => {
        const summary = {rounds: 0, claimed: 0, delivered: 0, retried: 0, failed: 0, deferred: 0, error: false};
        while (summary.rounds < maxRounds && now() < deadline) {
            try {
                const outcomes = await batch();
                summary.rounds++;
                summary.claimed += outcomes.length;
                for (const outcome of outcomes) {
                    const field = {delivered: 'delivered', retry: 'retried', failed: 'failed', deferred: 'deferred'}[outcome];
                    if (field) summary[field]++;
                }
                // Retrying a broken dependency in a tight loop makes an outage worse.
                if (!outcomes.length || outcomes.includes('retry') || outcomes.includes('deferred')) break;
            } catch { summary.error = true; break; }
        }
        return [name, summary];
    }));
    return Object.fromEntries(results);
}

export function workerFetch(signal, fetcher = fetch) {
    return async (input, init) => {
        const request = new Request(input, init);
        const response = await fetcher(new Request(request, {
            signal: AbortSignal.any([request.signal, signal, AbortSignal.timeout(6000)]),
        }));
        // Include the response body in the timeout, not only the headers.
        const bytes = await response.arrayBuffer();
        return new Response([204,205,304].includes(response.status) ? null : bytes,
            {status: response.status, statusText: response.statusText, headers: response.headers});
    };
}
