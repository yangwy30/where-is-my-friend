import {FlightLookupError, fetchFlightLookup} from './flight-lookup.mjs';

// SQL owns the lease and budget across Edge instances, accounts and background jobs.
export async function sharedFlightLookup(rpc, actor, tripID, input, key, {
    provider = fetchFlightLookup, delay = ms => new Promise(resolve => setTimeout(resolve, ms)),
} = {}) {
    const token = crypto.randomUUID();
    let reservation;
    for (const wait of [0, 350, 700, 1200]) {
        if (wait) await delay(wait);
        reservation = await rpc('wif_flight_lookup_acquire', {
            p_user_id: actor, p_trip_id: tripID, p_number: input.flightNumber, p_date: input.date, p_token: token,
        });
        if (reservation.cached) return reservation.cached;
        if (reservation.acquired) break;
        if (!reservation.pending) throw new FlightLookupError(503, 'Flight lookup is temporarily unavailable.');
    }
    if (!reservation.acquired) throw new FlightLookupError(503, 'This flight is being checked. Please try again shortly.');
    try {
        const result = await provider(input, key);
        const saved = await rpc('wif_flight_lookup_finish', {
            p_number: input.flightNumber, p_date: input.date, p_token: token, p_result: result,
        });
        if (!saved) throw new FlightLookupError(503, 'Flight lookup took too long. Please try again.');
        return result;
    } catch (error) {
        // Failed provider attempts stay charged. A short shared cooldown prevents a retry storm.
        try { await rpc('wif_flight_lookup_finish', {p_number: input.flightNumber, p_date: input.date, p_token: token, p_result: null}); }
        catch { /* Lease expiry provides recovery if the database is unavailable. */ }
        throw error;
    }
}
