import { createHash } from "node:crypto";

export const legacyColumns = {
    trips: ["id", "pin", "name", "start_date", "end_date", "destination_airport", "return_airport", "created_at"],
    participants: ["id", "trip_id", "name", "color", "home_airport", "destination_airport", "joined_at"],
    flights: ["id", "trip_id", "flight_number", "airline", "departure", "arrival", "date", "duration", "status", "aircraft", "gate", "added_by", "added_at"],
    notes: ["id", "trip_id", "content", "author", "created_at"],
    push_subscriptions: ["id", "trip_id", "participant_name", "subscription_json", "created_at"],
};

export function transformSnapshot(snapshot) {
    if (snapshot.formatVersion !== 1 || !/^[a-z]{20}$/.test(snapshot.sourceProject ?? "")) throw new Error("Unsupported snapshot");
    for (const [table, columns] of Object.entries(legacyColumns)) {
        if (!Array.isArray(snapshot[table])) throw new Error(`Missing ${table}`);
        const ids = new Set();
        for (const row of snapshot[table]) {
            if (!row || typeof row !== "object" || !row.id || ids.has(row.id)) throw new Error(`Invalid or duplicate ID in ${table}`);
            ids.add(row.id);
            if (Object.keys(row).some(key => !columns.includes(key))) throw new Error(`Unmapped source column in ${table}`);
        }
    }
    const tripIDs = new Set(snapshot.trips.map(t => t.id));
    for (const table of ["participants", "flights", "notes", "push_subscriptions"]) {
        if (snapshot[table].some(row => !tripIDs.has(row.trip_id))) throw new Error(`Orphaned row in ${table}`);
    }
    const trips = snapshot.trips.map(({ pin, ...trip }) => ({
        ...trip, source_project_ref: snapshot.sourceProject, legacy_imported_at: snapshot.exportedAt,
    }));
    const participants = snapshot.participants.map(p => ({ ...p, user_id: null }));
    let unmatchedFlights = 0;
    let unclassifiedDirections = 0;
    const flights = snapshot.flights.map(f => {
        const matching = participants.filter(p => p.trip_id === f.trip_id && p.name === f.added_by);
        const participant_id = matching.length === 1 ? matching[0].id : null;
        if (!participant_id) unmatchedFlights++;
        const destination = trips.find(t => t.id === f.trip_id)?.destination_airport;
        const departure = f.departure?.code;
        const arrival = f.arrival?.code;
        const direction = destination && arrival === destination && departure !== destination ? "outbound"
            : destination && departure === destination && arrival !== destination ? "inbound" : null;
        if (!direction) unclassifiedDirections++;
        return { ...f, participant_id, direction };
    });
    return {
        rows: { trips, participants, flights, notes: snapshot.notes.map(n => ({ ...n })) },
        report: {
            counts: { trips: trips.length, participants: participants.length, flights: flights.length, notes: snapshot.notes.length },
            membershipsGranted: 0,
            pinsCopied: 0,
            subscriptionsNotActivated: snapshot.push_subscriptions.length,
            unmatchedFlights,
            unclassifiedDirections,
        },
    };
}

// Parameterized inserts only. Table and column names are fixed by the transform.
// This helper is used by the LOCAL rehearsal, not by a deployment command.
export async function importIntoLocalDatabase(database, snapshot, rawSnapshot) {
    const plan = transformSnapshot(snapshot);
    await database.exec("begin");
    try {
        for (const [table, rows] of Object.entries(plan.rows)) {
            for (const row of rows) {
                const keys = Object.keys(row);
                await database.query(`insert into public.${table} (${keys.join(",")}) values (${keys.map((_, i) => `$${i + 1}`).join(",")})`,
                    keys.map(key => row[key]));
            }
        }
        await database.query("insert into public.trip_import_batches(source_project_ref,snapshot_sha256,counts) values ($1,$2,$3)",
            [snapshot.sourceProject, createHash("sha256").update(rawSnapshot).digest("hex"), plan.report.counts]);
        await database.exec("commit");
    } catch (error) {
        await database.exec("rollback");
        throw error;
    }
    return plan.report;
}
