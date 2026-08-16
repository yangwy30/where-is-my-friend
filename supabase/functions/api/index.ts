import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import { isUUID, normalizeAPIPath } from "../_shared/domain.mjs";
import { encryptAPNSToken, hashAPNSToken, normalizeAPNSToken } from "../_shared/push-security.mjs";

type JsonRecord = Record<string, unknown>;

class APIError extends Error {
    constructor(readonly status: number, message: string) {
        super(message);
    }
}

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "apikey, authorization, content-type, x-client-info",
    "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
};

const supabaseURL = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!supabaseURL || !serviceRoleKey) {
    throw new Error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.");
}

const database = createClient(supabaseURL, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
});

function json(value: unknown, status = 200): Response {
    return new Response(JSON.stringify(value), {
        status,
        headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
    });
}

function empty(status = 204): Response {
    return new Response(null, { status, headers: corsHeaders });
}

function signedOutSnapshot() {
    return {
        schemaVersion: 2,
        isAuthenticated: false,
        currentUser: {
            id: "00000000-0000-0000-0000-000000000000",
            displayName: "Guest",
            username: "guest",
            appleUserID: null,
            avatarPalette: 1,
        },
        currentPresence: { city: null, countryCode: null, updatedAt: null, source: "manual" },
        sharingPreferences: {
            citySharingEnabled: true,
            backgroundUpdatesEnabled: false,
            notificationPreviewEnabled: true,
        },
        friends: [],
        friendRequests: [],
        friendPreferences: [],
        colocationEvents: [],
        colocationSessions: [],
        blockedPeople: [],
        lastSyncedAt: new Date().toISOString(),
        syncState: "synced",
    };
}

async function readBody(request: Request): Promise<JsonRecord> {
    try {
        const body = await request.json();
        if (!body || Array.isArray(body) || typeof body !== "object") throw new Error();
        return body as JsonRecord;
    } catch {
        throw new APIError(400, "A JSON object body is required.");
    }
}

function requiredString(body: JsonRecord, key: string): string {
    const value = body[key];
    if (typeof value !== "string" || value.trim() === "") {
        throw new APIError(400, `Missing ${key}.`);
    }
    return value;
}

function requiredBoolean(body: JsonRecord, key: string): boolean {
    const value = body[key];
    if (typeof value !== "boolean") throw new APIError(400, `Missing ${key}.`);
    return value;
}

function requiredInteger(body: JsonRecord, key: string): number {
    const value = body[key];
    if (!Number.isInteger(value)) throw new APIError(400, `Missing ${key}.`);
    return value as number;
}

function pushConfiguration(environment: string): { bundleID: string; urlScheme: string } {
    if (environment !== "sandbox" && environment !== "production") {
        throw new APIError(400, "Invalid APNs environment.");
    }
    const suffix = environment === "sandbox" ? "SANDBOX" : "PRODUCTION";
    const bundleID = Deno.env.get(`APNS_${suffix}_BUNDLE_ID`);
    const urlScheme = Deno.env.get(`APNS_${suffix}_URL_SCHEME`);
    if (!bundleID || !urlScheme) throw new APIError(503, "Push registration is not configured.");
    return { bundleID, urlScheme };
}

function databaseStatus(message: string): number {
    const lower = message.toLowerCase();
    if (lower.includes("permission denied") || lower.includes("not permitted")) return 500;
    if (lower.includes("already") || lower.includes("exists") || lower.includes("taken") || lower.includes("unique")) {
        return 409;
    }
    if (lower.includes("no user") || lower.includes("no longer") || lower.includes("unavailable")) return 404;
    return 400;
}

function throwDatabaseError(error: { message: string } | null): never {
    const message = error?.message || "The database request failed.";
    const status = databaseStatus(message);
    throw new APIError(status, status >= 500 ? "The server could not complete the request." : message);
}

async function rpc(name: string, parameters: JsonRecord): Promise<unknown> {
    const { data, error } = await database.rpc(name, parameters);
    if (error) throwDatabaseError(error);
    if (data === null) throw new APIError(404, "The requested account is unavailable.");
    return data;
}

type Authorization = { authUserID: string; userID: string | null };

async function authorize(request: Request): Promise<Authorization> {
    const header = request.headers.get("Authorization") || "";
    const match = /^Bearer\s+(.+)$/i.exec(header);
    if (!match) throw new APIError(401, "Authentication is required.");

    // getUser validates the bearer token with Supabase Auth. The app profile is
    // then resolved exclusively from the verified Auth UUID, never client input.
    const { data: authData, error: authError } = await database.auth.getUser(match[1]);
    if (authError || !authData.user) throw new APIError(401, "The session expired.");

    const { data: userID, error: userError } = await database.rpc("wif_resolve_app_user", {
        p_auth_user_id: authData.user.id,
    });
    if (userError) throwDatabaseError(userError);
    if (userID !== null && (typeof userID !== "string" || !isUUID(userID))) {
        throw new APIError(500, "The server could not resolve the account.");
    }
    return { authUserID: authData.user.id, userID: userID as string | null };
}

async function handle(request: Request): Promise<Response> {
    if (request.method === "OPTIONS") return empty();
    const path = normalizeAPIPath(request.url);
    const segments = path.split("/").filter(Boolean);

    const authorization = await authorize(request);

    if (request.method === "POST" && path === "/v1/auth/bootstrap") {
        const body = await readBody(request);
        const displayName = body.displayName;
        if (displayName !== null && displayName !== undefined && typeof displayName !== "string") {
            throw new APIError(400, "Invalid displayName.");
        }
        const userID = await rpc("wif_ensure_app_user", {
            p_auth_user_id: authorization.authUserID,
            p_display_name: typeof displayName === "string" ? displayName : null,
        });
        if (typeof userID !== "string" || !isUUID(userID)) {
            throw new APIError(500, "The account could not be initialized.");
        }
        return json(await rpc("wif_snapshot", { p_user_id: userID }));
    }

    if (!authorization.userID) {
        throw new APIError(409, "The account profile must be initialized.");
    }
    const userID = authorization.userID;

    if (request.method === "GET" && path === "/v1/bootstrap") {
        return json(await rpc("wif_snapshot", { p_user_id: userID }));
    }
    if (request.method === "POST" && path === "/v1/auth/logout") {
        return json(signedOutSnapshot());
    }
    if (request.method === "DELETE" && path === "/v1/account") {
        const requestedAt = new Date().toISOString();
        const { data: deletionRequest, error: requestError } = await database
            .from("deletion_requests")
            .insert({ user_id: userID, requested_at: requestedAt })
            .select("id")
            .single();
        if (requestError || !deletionRequest) {
            throw new APIError(503, "Account deletion could not be started. Please try again.");
        }

        // Hard-deleting the Supabase Auth identity cascades through app_users to
        // friendships, presence, push devices, same-city events, and delivery
        // records. The request has no user foreign key so an interrupted attempt
        // can be diagnosed without retaining the account itself.
        const { error: deletionError } = await database.auth.admin.deleteUser(
            authorization.authUserID,
        );
        if (deletionError) {
            throw new APIError(503, "Account deletion is still pending. Please try again.");
        }

        const { error: cleanupError } = await database
            .from("deletion_requests")
            .delete()
            .eq("id", deletionRequest.id);
        if (cleanupError) console.error("Account deletion request cleanup failed.", cleanupError);
        return json(signedOutSnapshot());
    }
    if (request.method === "PATCH" && path === "/v1/profile") {
        const body = await readBody(request);
        return json(await rpc("wif_update_profile", {
            p_user_id: userID,
            p_display_name: requiredString(body, "displayName"),
            p_username: requiredString(body, "username"),
            p_avatar_palette: requiredInteger(body, "avatarPalette"),
        }));
    }
    if (request.method === "POST" && path === "/v1/friends/requests") {
        const body = await readBody(request);
        return json(await rpc("wif_send_friend_request", {
            p_user_id: userID,
            p_username: requiredString(body, "username"),
        }));
    }
    if (request.method === "PATCH" && segments.length === 4 && segments[1] === "friends" && segments[2] === "requests") {
        if (!isUUID(segments[3])) throw new APIError(400, "Invalid request ID.");
        const body = await readBody(request);
        return json(await rpc("wif_respond_friend_request", {
            p_user_id: userID,
            p_request_id: segments[3],
            p_response: requiredString(body, "response"),
        }));
    }
    if (request.method === "DELETE" && segments.length === 3 && segments[1] === "friends") {
        if (!isUUID(segments[2])) throw new APIError(400, "Invalid friend ID.");
        return json(await rpc("wif_remove_friend", { p_user_id: userID, p_friend_id: segments[2] }));
    }
    if ((request.method === "PUT" || request.method === "DELETE")
        && segments.length === 4 && segments[1] === "users" && segments[3] === "block") {
        if (!isUUID(segments[2])) throw new APIError(400, "Invalid user ID.");
        const functionName = request.method === "PUT" ? "wif_block_user" : "wif_unblock_user";
        return json(await rpc(functionName, { p_user_id: userID, p_blocked_id: segments[2] }));
    }
    if (request.method === "PATCH" && segments.length === 4
        && segments[1] === "friends" && segments[3] === "favorite") {
        if (!isUUID(segments[2])) throw new APIError(400, "Invalid friend ID.");
        const body = await readBody(request);
        return json(await rpc("wif_set_favorite", {
            p_user_id: userID,
            p_friend_id: segments[2],
            p_is_favorite: requiredBoolean(body, "isFavorite"),
        }));
    }
    if (request.method === "PATCH" && segments.length === 4
        && segments[1] === "friends" && segments[3] === "preferences") {
        if (!isUUID(segments[2])) throw new APIError(400, "Invalid friend ID.");
        const body = await readBody(request);
        return json(await rpc("wif_set_friend_preference", {
            p_user_id: userID,
            p_friend_id: segments[2],
            p_shares_city: requiredBoolean(body, "sharesMyCity"),
            p_same_city_alert: requiredBoolean(body, "sameCityAlertEnabled"),
        }));
    }
    if (request.method === "PATCH" && path === "/v1/sharing") {
        const body = await readBody(request);
        return json(await rpc("wif_set_sharing_preferences", {
            p_user_id: userID,
            p_city_sharing_enabled: requiredBoolean(body, "citySharingEnabled"),
            p_background_updates_enabled: requiredBoolean(body, "backgroundUpdatesEnabled"),
            p_notification_preview_enabled: requiredBoolean(body, "notificationPreviewEnabled"),
        }));
    }
    if (request.method === "PUT" && path === "/v1/presence/current") {
        const body = await readBody(request);
        const clientUpdatedAt = requiredString(body, "clientUpdatedAt");
        if (!Number.isFinite(Date.parse(clientUpdatedAt))) throw new APIError(400, "Invalid update time.");
        return json(await rpc("wif_update_presence", {
            p_user_id: userID,
            p_city: requiredString(body, "city"),
            p_country_code: requiredString(body, "countryCode"),
            p_source: requiredString(body, "source"),
            p_client_updated_at: clientUpdatedAt,
        }));
    }
    if ((request.method === "PUT" || request.method === "DELETE") && path === "/v1/devices/push-token") {
        const body = await readBody(request);
        if (body.platform !== undefined && body.platform !== "ios") {
            throw new APIError(400, "Invalid push platform.");
        }
        const installationID = requiredString(body, "installationID");
        if (!isUUID(installationID)) throw new APIError(400, "Invalid installation ID.");
        const environment = requiredString(body, "environment");
        const push = pushConfiguration(environment);

        if (request.method === "DELETE") {
            await rpc("wif_disable_push_device", {
                p_user_id: userID,
                p_installation_id: installationID,
                p_environment: environment,
            });
            return empty();
        }

        const encryptionKey = Deno.env.get("APNS_DEVICE_TOKEN_KEY");
        if (!encryptionKey) throw new APIError(503, "Push registration is not configured.");
        let token: string;
        try {
            token = normalizeAPNSToken(requiredString(body, "token"));
        } catch {
            throw new APIError(400, "Invalid APNs device token.");
        }
        await rpc("wif_register_push_device", {
            p_user_id: userID,
            p_installation_id: installationID,
            p_token_hash: await hashAPNSToken(token),
            p_encrypted_token: await encryptAPNSToken(token, encryptionKey),
            p_environment: environment,
            p_bundle_id: push.bundleID,
            p_url_scheme: push.urlScheme,
        });
        return empty();
    }

    throw new APIError(404, "Endpoint not found.");
}

Deno.serve(async request => {
    try {
        return await handle(request);
    } catch (error) {
        if (error instanceof APIError) return json({ message: error.message }, error.status);
        console.error(error);
        return json({ message: "The server could not complete the request." }, 500);
    }
});
