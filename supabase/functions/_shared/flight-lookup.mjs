// AeroDataBox via the existing RapidAPI subscription. Server-only; never return the key.
export class FlightLookupError extends Error {
    constructor(status, message) { super(message); this.status = status; }
}

export function flightLookupInput(number, date) {
    const flightNumber = typeof number === 'string' ? number.toUpperCase().replace(/\s/g, '') : '';
    if (!/^[A-Z0-9]{2,3}[0-9]{1,4}[A-Z]?$/.test(flightNumber) || typeof date !== 'string'
        || !/^\d{4}-\d{2}-\d{2}$/.test(date) || !Number.isFinite(Date.parse(date+'T12:00:00Z'))
        || new Date(date+'T12:00:00Z').toISOString().slice(0,10) !== date) {
        throw new FlightLookupError(400, 'Enter a valid flight number and departure date.');
    }
    return { flightNumber, date };
}

const text = value => typeof value === 'string' ? value.slice(0,200) : null;
const time = value => ({ local: text(value?.local), utc: text(value?.utc) });
function endpoint(value) {
    return {
        code: text(value?.airport?.iata), icao: text(value?.airport?.icao),
        city: text(value?.airport?.municipalityName), name: text(value?.airport?.name),
        timeZone: text(value?.airport?.timeZone),
        scheduledTime: time(value?.scheduledTime), revisedTime: time(value?.revisedTime),
        predictedTime: time(value?.predictedTime), runwayTime: time(value?.runwayTime),
        terminal: text(value?.terminal), gate: text(value?.gate),
        quality: Array.isArray(value?.quality) ? value.quality.map(text).filter(Boolean).slice(0,20) : [],
    };
}
function status(value) {
    switch (String(value).toLowerCase()) {
        case 'arrived': case 'landed': return 'landed';
        case 'canceled': case 'cancelled': return 'cancelled';
        case 'delayed': return 'delayed';
        case 'boarding': return 'boarding';
        case 'departed': case 'enroute': return 'airborne';
        case 'expected': case 'scheduled': return 'scheduled';
        case 'diverted': return 'diverted';
        default: return 'unknown';
    }
}

export function normalizeFlightResults(data, input, fetchedAt = new Date().toISOString()) {
    if (!Array.isArray(data)) throw new FlightLookupError(502, 'The flight provider returned an invalid response.');
    const seen = new Set();
    const flights = [];
    for (const item of data.slice(0,100)) {
        const departure = endpoint(item?.departure), arrival = endpoint(item?.arrival);
        // Never mix the previous night's arrival with the selected departure date.
        if (!departure.scheduledTime.local?.startsWith(input.date) || !departure.code || !arrival.code) continue;
        const id = [departure.code,arrival.code,departure.scheduledTime.local].join('|');
        if (seen.has(id)) continue;
        seen.add(id);
        flights.push({ id, flightNumber: text(item.number) ?? input.flightNumber, date: input.date,
            airline: text(item.airline?.name), departure, arrival,
            status: status(item.status), providerStatus: text(item.status), aircraft: text(item.aircraft?.model),
            providerUpdatedAt: text(item.lastUpdatedUtc) });
    }
    return { source: 'aerodatabox', flightNumber: input.flightNumber, date: input.date, fetchedAt, flights };
}

export async function fetchFlightLookup(input, apiKey, fetcher = fetch) {
    if (!apiKey) throw new FlightLookupError(503, 'Flight lookup is not configured.');
    const url = new URL(`https://aerodatabox.p.rapidapi.com/flights/number/${encodeURIComponent(input.flightNumber)}/${input.date}`);
    url.searchParams.set('dateLocalRole','Departure');
    url.searchParams.set('withAircraftImage','false');
    url.searchParams.set('withLocation','false');
    let response;
    try {
        response = await fetcher(url, { headers: { 'X-RapidAPI-Key': apiKey,
            'X-RapidAPI-Host':'aerodatabox.p.rapidapi.com', Accept:'application/json' }, signal: AbortSignal.timeout(15000) });
    } catch { throw new FlightLookupError(502, 'The flight provider could not be reached. Please try again.'); }
    if (response.status === 204 || response.status === 404) return normalizeFlightResults([],input);
    if ([401,402,403,429].includes(response.status)) {
        throw new FlightLookupError(503, 'Flight lookup is temporarily unavailable. Please try again later.');
    }
    if (!response.ok) throw new FlightLookupError(502, 'The flight provider could not complete the lookup.');
    try { return normalizeFlightResults(await response.json(),input); }
    catch (error) {
        if (error instanceof FlightLookupError) throw error;
        throw new FlightLookupError(502, 'The flight provider returned an invalid response.');
    }
}
