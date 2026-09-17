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

const database = createClient(supabaseURL, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
});

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

async function send(delivery: ClaimedDelivery, claimToken: string) {
    try {
        if (!delivery.kind) {
            const check = await database.rpc("wif_colocation_delivery_allowed", {p_id: delivery.delivery_id, p_token: claimToken});
            if (check.error) throw new Error("Could not verify current city sharing.");
            if (check.data !== true) {
                await complete(delivery, claimToken, {outcome: "failed", error: "Same-city presence is no longer current."});
                return "failed";
            }
        }
        const token = await providerToken();
        if (delivery.kind === "trip-reminder") {
            const check = await database.rpc("wif_trip_booking_allowed", {p_id:delivery.event_id,p_device:delivery.device_id});
            if (check.error) throw new Error("Could not verify trip reminder eligibility.");
            if (check.data !== true) {
                await complete(delivery,claimToken,{outcome:"failed"});
                return "failed";
            }
        }
        const deviceToken = await decryptAPNSToken(delivery.encrypted_apns_token, encryptionKey!);
        const host = delivery.environment === "sandbox"
            ? "https://api.sandbox.push.apple.com"
            : "https://api.push.apple.com";
        const response = await fetch(`${host}/3/device/${deviceToken}`, {
            method: "POST",
            signal: AbortSignal.timeout(15000),
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
        const classification = classifyAPNsResponse(response.status, errorBody.reason ?? "");
        const responseAPNsID = response.headers.get("apns-id");
        await complete(delivery, claimToken, {
            ...classification,
            error: response.ok ? undefined : `APNs ${response.status}: ${errorBody.reason ?? "Unknown"}`,
            apnsID: responseAPNsID && /^[0-9a-f-]{36}$/i.test(responseAPNsID) ? responseAPNsID : null,
        });
        return classification.outcome;
    } catch (error) {
        const message = error instanceof Error ? error.message : "Unknown APNs network failure";
        await complete(delivery, claimToken, {
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

    const claimToken = crypto.randomUUID();
    if (options?.action === "trip-reminders") {
        try {
            const outcomes = await deliverTripBookingReminders(database,claimToken,(delivery: ClaimedDelivery) => send(delivery,claimToken));
            return json({claimed:outcomes.length,delivered:outcomes.filter(value=>value==="delivered").length});
        } catch { return json({message:"Trip reminder queue unavailable."},503); }
    }
    const { data, error } = options?.action === "invitations" ? {data: [], error: null} : await database.rpc("wif_claim_notification_deliveries", {
        p_limit: 20,
        p_claim_token: claimToken,
    });
    if (error) return json({ message: "The notification queue could not be claimed." }, 500);
    const deliveries = (data ?? []) as ClaimedDelivery[];
    const outcomes: string[] = [];
    // Bound the extra pre-send database checks instead of bursting 20 at once.
    for (let offset = 0; offset < deliveries.length; offset += 3) {
        outcomes.push(...await Promise.all(deliveries.slice(offset, offset + 3).map(delivery => send(delivery, claimToken))));
    }
    let friendInvitationError = false;
    try {
        outcomes.push(...await deliverFriendInvitations(database, claimToken, (delivery: ClaimedDelivery) => send(delivery, claimToken)));
    } catch { friendInvitationError = true; }
    let invitationError = false;
    try {
        outcomes.push(...await deliverTripInvitations(database, claimToken, (delivery: ClaimedDelivery) => send(delivery, claimToken)));
    } catch { invitationError = true; }
    let upcomingError = false;
    try {
        if (options?.action !== "invitations") outcomes.push(...await deliverUpcoming(database, claimToken, (delivery: ClaimedDelivery) => send(delivery, claimToken)));
    } catch { upcomingError = true; }
    let bookingReminderError = false;
    try {
        if (options?.action !== "invitations") outcomes.push(...await deliverTripBookingReminders(database,claimToken,(delivery: ClaimedDelivery) => send(delivery,claimToken)));
    } catch { bookingReminderError = true; }
    return json({
        bookingReminderError,
        friendInvitationError,
        upcomingError,
        invitationError,
        claimed: outcomes.length,
        delivered: outcomes.filter(value => value === "delivered").length,
        retried: outcomes.filter(value => value === "retry").length,
        failed: outcomes.filter(value => value === "failed").length,
    });
});
