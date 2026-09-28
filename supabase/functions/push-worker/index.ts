import { backgroundObservation, postHeartbeat, postObservation, pushConfigurationReasons } from "../_shared/observability.mjs";
import { deliveryGate, drainQueues, workerFetch, settleBatch } from "../_shared/queue-drain.mjs";
import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import { importPKCS8, SignJWT } from "npm:jose@6.2.8";
import { classifyAPNsResponse, decryptAPNSToken } from "../_shared/push-security.mjs";
import { deliverUpcoming, normalizeAPNsPrivateKey } from "../_shared/travel-plans.mjs";
import { deliverTripInvitations } from "../_shared/trip-invitations.mjs";
import { deliverFriendInvitations } from "../_shared/friend-invitations.mjs";

import { deliverTripBookingReminders } from "../_shared/trip-booking-reminders.mjs";

type ClaimedDelivery = {
    kind?: "upcoming" | "trip-invitation" | "friend-invitation" | "trip-reminder";
    expires_at?: number;
    delivery_id: string;
    device_id: string;
    encrypted_apns_token: string;
    environment: "sandbox" | "production";
    bundle_id: string;
    event_id: string;
    title: string;
    body: string;
    deep_link: string;
};

type APNsError = { reason?: string };

const supabaseURL = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const workerSecret = Deno.env.get("PUSH_WORKER_SECRET");
const encryptionKey = Deno.env.get("APNS_DEVICE_TOKEN_KEY");
const apnsKeyID = Deno.env.get("APNS_KEY_ID");
const apnsTeamID = Deno.env.get("APNS_TEAM_ID");
const apnsPrivateKey = normalizeAPNsPrivateKey(Deno.env.get("APNS_PRIVATE_KEY"));
let cachedProviderToken: { value: string; createdAt: number } | null = null;
let providerTokenInFlight: Promise<string> | null = null;

if (!supabaseURL || !serviceRoleKey) throw new Error("Supabase service configuration is required.");


function json(value: unknown, status = 200) {
    return new Response(JSON.stringify(value), {
        status,
        headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
    });
}

function configured(): boolean {
    return Boolean(workerSecret && encryptionKey && apnsKeyID && apnsTeamID && apnsPrivateKey);
}

async function providerToken(): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    if (cachedProviderToken && now - cachedProviderToken.createdAt < 50 * 60) {
        return cachedProviderToken.value;
    }
    if (providerTokenInFlight) return providerTokenInFlight;
    providerTokenInFlight = (async () => {
        const key = await importPKCS8(apnsPrivateKey!, "ES256");
        const value = await new SignJWT({})
            .setProtectedHeader({ alg: "ES256", kid: apnsKeyID! })
            .setIssuer(apnsTeamID!)
            .setIssuedAt(now)
            .sign(key);
        cachedProviderToken = { value, createdAt: now };
        return value;
    })();
    try { return await providerTokenInFlight; }
    finally { providerTokenInFlight = null; }
}

async function complete(
    database: ReturnType<typeof createClient>,
    delivery: ClaimedDelivery,
    claimToken: string,
    result: { outcome: string; error?: string; apnsID?: string | null; retryAfterSeconds?: number | null; disableDevice?: boolean },
) {
    if (delivery.kind === "trip-reminder") {
        const { error } = await database.rpc("wif_trip_booking_complete", {
            p_id: delivery.delivery_id, p_token: claimToken, p_outcome: result.outcome, p_disable_device: result.disableDevice ?? false,
        });
        if (error) throw new Error("Could not complete trip reminder.");
        return;
    }
    if (delivery.kind === "friend-invitation") {
        const { error } = await database.rpc("wif_friend_invitation_complete", {
            p_id: delivery.delivery_id, p_token: claimToken, p_outcome: result.outcome,
            p_error: result.error?.slice(0, 500) ?? null, p_apns_id: result.apnsID ?? null,
            p_disable_device: result.disableDevice ?? false,
        });
        if (error) throw new Error("Could not complete friend invitation delivery.");
        return;
    }
    if (delivery.kind === "trip-invitation") {
        const { error } = await database.rpc("wif_trip_invitation_complete", {
            p_id: delivery.delivery_id, p_token: claimToken, p_outcome: result.outcome,
            p_error: result.error?.slice(0, 500) ?? null, p_apns_id: result.apnsID ?? null,
            p_disable_device: result.disableDevice ?? false,
        });
        if (error) throw new Error("Could not complete trip invitation delivery.");
        return;
    }
    if (delivery.kind === "upcoming") {
        const { error } = await database.rpc("wif_travel_complete", {
            p_id: delivery.delivery_id, p_token: claimToken, p_outcome: result.outcome,
            p_disable_device: result.disableDevice ?? false,
        });
        if (error) throw new Error("Could not complete upcoming reminder.");
        return;
    }
    const { error } = await database.rpc("wif_complete_notification_delivery", {
        p_delivery_id: delivery.delivery_id,
        p_claim_token: claimToken,
        p_outcome: result.outcome,
        p_error: result.error?.slice(0, 500) ?? null,
        p_apns_id: result.apnsID ?? null,
        p_retry_after_seconds: result.retryAfterSeconds ?? null,
        p_disable_device: result.disableDevice ?? false,
    });
    if (error) throw new Error(`Could not complete delivery ${delivery.delivery_id}: ${error.message}`);
}

async function send(database: ReturnType<typeof createClient>, delivery: ClaimedDelivery, claimToken: string, signal: AbortSignal) {
    try {
        if (!delivery.kind) {
            const check = await database.rpc("wif_colocation_delivery_allowed", {p_id: delivery.delivery_id, p_token: claimToken});
            if (check.error) throw new Error("Could not verify current city sharing.");
            if (check.data !== true) {
                await complete(database, delivery, claimToken, {outcome: "failed", error: "Same-city presence is no longer current."});
                return "failed";
            }
        }
        const token = await providerToken();
        if (delivery.kind === "trip-reminder") {
            const check = await database.rpc("wif_trip_booking_allowed", {p_id:delivery.event_id,p_device:delivery.device_id});
            if (check.error) throw new Error("Could not verify trip reminder eligibility.");
            if (check.data !== true) {
                await complete(database, delivery,claimToken,{outcome:"failed"});
                return "failed";
            }
        }
        const deviceToken = await decryptAPNSToken(delivery.encrypted_apns_token, encryptionKey!);
        const host = delivery.environment === "sandbox"
            ? "https://api.sandbox.push.apple.com"
            : "https://api.push.apple.com";
        const response = await fetch(`${host}/3/device/${deviceToken}`, {
            method: "POST",
            signal: AbortSignal.any([signal, AbortSignal.timeout(12000)]),
            headers: {
                authorization: `bearer ${token}`,
                "apns-topic": delivery.bundle_id,
                "apns-push-type": "alert",
                "apns-priority": "10",
                "apns-expiration": delivery.kind === "trip-invitation" || delivery.kind === "friend-invitation" || delivery.kind === "trip-reminder" ? String(delivery.expires_at ?? 0) : "0",
                "apns-collapse-id": delivery.event_id,
                "content-type": "application/json",
            },
            body: JSON.stringify({
                aps: {
                    alert: { title: delivery.title, body: delivery.body },
                    sound: "default",
                    "thread-id": delivery.kind === "trip-reminder" ? "trip-reminders" : delivery.kind === "friend-invitation" ? "friend-invitations" : delivery.kind === "trip-invitation" ? "trip-invitations" : delivery.kind === "upcoming" ? "upcoming" : "colocation",
                },
                deepLink: delivery.deep_link,
                eventID: delivery.event_id,
            }),
        });
        const errorBody = response.ok ? {} : await response.json().catch(() => ({})) as APNsError;
        if (Deno.env.get("WIF_OBSERVABILITY_ENABLED") === "true" && pushConfigurationReasons.has(errorBody.reason ?? "")) {
            backgroundObservation(postObservation(supabaseURL!, serviceRoleKey!, {eventID: crypto.randomUUID(), feature: "notifications", kind: "push_configuration", status: response.status, elapsedMs: 0, version: "server"}));
        }
        const classification = classifyAPNsResponse(response.status, errorBody.reason ?? "");
        const responseAPNsID = response.headers.get("apns-id");
        await complete(database, delivery, claimToken, {
            ...classification,
            error: response.ok ? undefined : `APNs ${response.status}: ${errorBody.reason ?? "Unknown"}`,
            apnsID: responseAPNsID && /^[0-9a-f-]{36}$/i.test(responseAPNsID) ? responseAPNsID : null,
        });
        return classification.outcome;
    } catch (error) {
        const message = error instanceof Error ? error.message : "Unknown APNs network failure";
        await complete(database, delivery, claimToken, {
            outcome: "retry",
            error: message,
            retryAfterSeconds: 300,
        });
        return "retry";
    }
}

Deno.serve(async request => {
    if (request.method !== "POST") return json({ message: "Method not allowed." }, 405);
    if (!workerSecret || request.headers.get("Authorization") !== `Bearer ${workerSecret}`) {
        return json({ message: "Authentication is required." }, 401);
    }
    if (!configured()) return json({ message: "Push delivery is not configured." }, 503);

    // Authenticated, read-only readiness probe. Never claims work or sends APNs.
    const options = await request.json().catch(() => ({}));
    if (options?.action === "check-signing") {
        try { await providerToken(); return json({ signingReady: true }); }
        catch (error) {
            return json({ signingReady: false,
                errorType: error instanceof Error ? error.name : "Unknown",
                pkcs8Envelope: /^-{5}BEGIN PRIVATE KEY-{5}/.test(apnsPrivateKey),
            }, 503);
        }
    }

    const started = Date.now();
    const deadline = started + 35000;
    const signal = AbortSignal.timeout(55000);
    const database = createClient(supabaseURL!, serviceRoleKey!, {
        auth: { autoRefreshToken: false, persistSession: false },
        db: { retry: false },
        global: { fetch: workerFetch(signal) },
    });
    if (options?.action === "check-capacity") {
        const health = await database.rpc("wif_capacity_health");
        return health.error ? json({message: "Capacity health unavailable."}, 503) : json(health.data);
    }
    const slotToken = crypto.randomUUID();
    const lane = ["invitations", "trip-reminders", "colocation"].includes(options?.action) ? "interactive" : "scheduled";
    const slot = await database.rpc("wif_push_worker_acquire", {p_token: slotToken, p_lane: lane});
    if (slot.error) return json({message: "Worker capacity unavailable."}, 503);
    if (slot.data !== true) return json({state: "busy", claimed: 0, delivered: 0});
    const run = deliveryGate({concurrency: 6, deadline});
    const batch = (deliver: Function) => async () => {
        const token = crypto.randomUUID();
        return deliver(database, token, (row: ClaimedDelivery) => send(database, row, token, signal), {run});
    };
    const queues: Record<string, () => Promise<string[]>> = {};
    if (options?.action !== "invitations" && options?.action !== "trip-reminders") {
        queues.colocation = async () => {
            const token = crypto.randomUUID();
            const {data, error} = await database.rpc("wif_claim_notification_deliveries", {p_limit: 20, p_claim_token: token});
            if (error) throw new Error("Notification queue unavailable.");
            return settleBatch((data ?? []).map((row: ClaimedDelivery) => run(() => send(database, row, token, signal))));
        };
        if (options?.action !== "colocation") queues.upcoming = batch(deliverUpcoming);
    }
    if (options?.action !== "trip-reminders" && options?.action !== "colocation") {
        queues.friendInvitations = batch(deliverFriendInvitations);
        queues.tripInvitations = batch(deliverTripInvitations);
    }
    if (options?.action !== "invitations" && options?.action !== "colocation") queues.booking = batch(deliverTripBookingReminders);
    let summary;
    try { summary = await drainQueues(queues, {deadline, maxRounds: 10}); }
    finally {
        // On a timeout/crash the 60-second SQL lease, not a local timer, restores capacity.
        try { await database.rpc("wif_push_worker_release", {p_token: slotToken, p_lane: lane}); } catch { /* expires */ }
    }
    const totals = Object.values(summary).reduce((sum: Record<string, number>, queue: any) => {
        for (const field of ["claimed", "delivered", "retried", "failed", "deferred"]) sum[field] += queue[field];
        return sum;
    }, {claimed: 0, delivered: 0, retried: 0, failed: 0, deferred: 0});
    const result = {...totals, queues: summary, elapsedMs: Date.now() - started,
        friendInvitationError: summary.friendInvitations?.error ?? false,
        invitationError: summary.tripInvitations?.error ?? false,
        upcomingError: summary.upcoming?.error ?? false,
        bookingReminderError: summary.booking?.error ?? false};
    console.log(JSON.stringify({event: "push_queue_drain", ...result}));
    if (Deno.env.get("WIF_OBSERVABILITY_ENABLED") === "true" && lane === "scheduled") {
        backgroundObservation(postHeartbeat(supabaseURL!, serviceRoleKey!, "push", !Object.values(summary).some((queue: any) => queue.error)));
    }
    return json(result, Object.values(summary).some((queue: any) => queue.error) ? 503 : 200);
});
