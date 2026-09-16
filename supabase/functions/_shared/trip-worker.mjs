import { fetchFlightLookup } from './flight-lookup.mjs';

// One bounded reservation per invocation. Database leases and quotas remain authoritative.
export async function refreshOneFlight(rpc, apiKey, fetcher = fetch) {
    if (!apiKey) return { state: 'not_configured', updated: 0 };
    const token = crypto.randomUUID();
    const job = await rpc('wif_trip_claim_refresh', { p_token: token });
    if (!job) return { state: 'idle', updated: 0 };
    let result = null;
    try { result = await fetchFlightLookup(job, apiKey, fetcher); }
    catch { /* Persist failure without leaking provider credentials or inventing a flight. */ }
    const updated = await rpc('wif_trip_finish_refresh', {
        p_token: token, p_number: job.flightNumber, p_date: job.date, p_result: result,
    });
    return { state: result ? 'checked' : 'provider_unavailable', updated };
}

export async function deliverTripUpdates(rpc, sender) {
    const token = crypto.randomUUID();
    const claims = await rpc('wif_trip_claim_deliveries', { p_claim_token: token });
    const outcomes = await Promise.all(claims.map(async ({ delivery_id: id }) => {
        let result = { outcome: 'failed', disableDevice: false };
        try {
            // Re-check membership, blocks, preference, expiry and device ownership immediately before send.
            const delivery = await rpc('wif_trip_prepare_delivery', { p_id: id, p_token: token });
            if (delivery) result = await sender(delivery);
        } catch { result = { outcome: 'retry', disableDevice: false }; }
        await rpc('wif_trip_complete_delivery', {
            p_id: id, p_token: token, p_outcome: result.outcome, p_disable_device: result.disableDevice ?? false,
        });
        return result.outcome;
    }));
    return { claimed: outcomes.length, delivered: outcomes.filter(x => x === 'delivered').length };
}
