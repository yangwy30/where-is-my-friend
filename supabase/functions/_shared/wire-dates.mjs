// Postgres and Date#toISOString write fractional seconds ("2026-10-16T23:34:29.852301+00:00").
// Apps up to 1.0.8 (35) decode dates with JSONDecoder's `.iso8601`, which rejects fractional
// seconds on iOS 18, so every response failed there and sign-in signed itself out.
// Responses send whole seconds until no supported build needs this.
const fractionalTimestamp = /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})\.\d+(Z|[+-]\d{2}:\d{2})$/;

export function wholeSecondTimestamps(_key, value) {
    return typeof value === "string" ? value.replace(fractionalTimestamp, "$1$2") : value;
}
