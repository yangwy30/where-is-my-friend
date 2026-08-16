import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import { importPKCS8, SignJWT } from "npm:jose@6.2.8";
import { classifyAPNsResponse, decryptAPNSToken } from "../_shared/push-security.mjs";

type ClaimedDelivery = {
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
const apnsPrivateKey = Deno.env.get("APNS_PRIVATE_KEY")?.replaceAll("\\n", "\n");
let cachedProviderToken: { value: string; createdAt: number } | null = null;

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
    const key = await importPKCS8(apnsPrivateKey!, "ES256");
    const value = await new SignJWT({})
        .setProtectedHeader({ alg: "ES256", kid: apnsKeyID! })
        .setIssuer(apnsTeamID!)
        .setIssuedAt(now)
        .sign(key);
    cachedProviderToken = { value, createdAt: now };
    return value;
}

async function complete(
    delivery: ClaimedDelivery,
    claimToken: string,
    result: { outcome: string; error?: string; apnsID?: string | null; retryAfterSeconds?: number | null; disableDevice?: boolean },
) {
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

async function send(delivery: ClaimedDelivery, claimToken: string, token: string) {
    try {
        const deviceToken = await decryptAPNSToken(delivery.encrypted_apns_token, encryptionKey!);
        const host = delivery.environment === "sandbox"
            ? "https://api.sandbox.push.apple.com"
            : "https://api.push.apple.com";
        const response = await fetch(`${host}/3/device/${deviceToken}`, {
            method: "POST",
            headers: {
                authorization: `bearer ${token}`,
                "apns-topic": delivery.bundle_id,
                "apns-push-type": "alert",
                "apns-priority": "10",
                "apns-expiration": "0",
                "apns-collapse-id": delivery.event_id,
                "content-type": "application/json",
            },
            body: JSON.stringify({
                aps: {
                    alert: { title: delivery.title, body: delivery.body },
                    sound: "default",
                    "thread-id": "colocation",
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

    const claimToken = crypto.randomUUID();
    const { data, error } = await database.rpc("wif_claim_notification_deliveries", {
        p_limit: 20,
        p_claim_token: claimToken,
    });
    if (error) return json({ message: "The notification queue could not be claimed." }, 500);
    const deliveries = (data ?? []) as ClaimedDelivery[];
    if (deliveries.length === 0) return json({ claimed: 0, delivered: 0, retried: 0, failed: 0 });

    const token = await providerToken();
    const outcomes = await Promise.all(deliveries.map(delivery => send(delivery, claimToken, token)));
    return json({
        claimed: outcomes.length,
        delivered: outcomes.filter(value => value === "delivered").length,
        retried: outcomes.filter(value => value === "retry").length,
        failed: outcomes.filter(value => value === "failed").length,
    });
});
