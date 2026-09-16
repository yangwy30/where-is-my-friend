import { presenceAdministrativeArea } from "../_shared/city-regions.mjs";
import { pushRoute } from "../_shared/push-routing.mjs";
import { wakeInvitationWorker } from "../_shared/invitation-wakeup.mjs";
import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import { isUUID, normalizeAPIPath } from "../_shared/domain.mjs";
import { encryptAPNSToken, hashAPNSToken, normalizeAPNSToken } from "../_shared/push-security.mjs";
import { FlightLookupError, flightLookupInput, fetchFlightLookup } from "../_shared/flight-lookup.mjs";
import { travelPlanInput } from "../_shared/travel-plans.mjs";
import { resilientSupabaseFetch, temporaryStatus, authFailureStatus } from "../_shared/upstream-policy.mjs";

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
    db: { retry: false }, // One retry policy only; never let SDK defaults replay writes.
    global: { fetch: resilientSupabaseFetch(new URL(supabaseURL).origin) },
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

function pushConfiguration(body: JsonRecord): { bundleID: string; urlScheme: string } {
    try { return pushRoute(body, (key: string) => Deno.env.get(key)); }
    catch { throw new APIError(400, "Unsupported notification app or environment. Please update the app."); }
}

function databaseStatus(message: string): number {
    const lower = message.toLowerCase();
    if (lower.includes("flight lookup limit reached")) return 429;
    if (lower.includes("trip access denied") || lower.includes("travel access denied")) return 403;
    if (lower.includes("conflict")) return 409;
    if (lower.includes("permission denied") || lower.includes("not permitted")) return 500;
    if (lower.includes("already") || lower.includes("exists") || lower.includes("taken") || lower.includes("unique")) {
        return 409;
    }
    if (lower.includes("no user") || lower.includes("no longer") || lower.includes("unavailable")) return 404;
    return 400;
}

function throwDatabaseError(error: { message: string; code?: string } | null, upstreamStatus?: number): never {
    const message = error?.message || "The database request failed.";
    const transient = temporaryStatus(error, upstreamStatus);
    // Unknown SQL/infrastructure failures must not look like invalid user input.
    const status = transient ?? (error?.code && !['P0001', '23505', '23514', '22023'].includes(error.code)
        ? 500 : databaseStatus(message));
    throw new APIError(status, status >= 500 ? "The service is temporarily unavailable. Please try again." : message);
}

async function rpc(name: string, parameters: JsonRecord): Promise<unknown> {
    const { data, error, status } = await database.rpc(name, parameters);
    if (error) throwDatabaseError(error, status);
    if (data === null) throw new APIError(404, "The requested account is unavailable.");
    return data;
}

function wakeInvitations() {
    wakeInvitationWorker({baseURL: supabaseURL, secret: Deno.env.get("PUSH_WORKER_SECRET"),
        waitUntil: typeof EdgeRuntime !== "undefined" ? (task: Promise<unknown>) => EdgeRuntime.waitUntil(task) : undefined});
}

type Authorization = { authUserID: string; userID: string | null };

async function authorize(request: Request): Promise<Authorization> {
    const header = request.headers.get("Authorization") || "";
    const match = /^Bearer\s+(.+)$/i.exec(header);
    if (!match) throw new APIError(401, "Authentication is required.");

    // getUser validates the bearer token with Supabase Auth. The app profile is
    // then resolved exclusively from the verified Auth UUID, never client input.
    const { data: authData, error: authError } = await database.auth.getUser(match[1]);
    if (authError || !authData?.user) {
        const status = authFailureStatus(authError);
        throw new APIError(status, status === 401 ? "The session expired."
            : "Sign-in verification is temporarily unavailable. Please try again.");
    }

    const { data: userID, error: userError, status: userStatus } = await database.rpc("wif_resolve_app_user", {
        p_auth_user_id: authData.user.id,
    });
    if (userError) throwDatabaseError(userError, userStatus);
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

    if (request.method === "GET" && path === "/v1/travel-plans") {
        return json(await rpc("wif_travel_snapshot", { p_user_id: userID }));
    }
    if (segments[0] === "v1" && segments[1] === "travel-plans" && segments.length === 3) {
        if (!isUUID(segments[2])) throw new APIError(400, "Invalid plan ID.");
        if (request.method === "PUT") {
            const body = await readBody(request);
            let payload;
            try { payload = travelPlanInput(body); } catch (e) {
                throw new APIError(400, e instanceof Error ? e.message : "Invalid travel plan.");
            }
            const saveRPC = Object.hasOwn(payload, "p_allow_friend_browsing") ? "wif_travel_save_v2" : "wif_travel_save";
            return json(await rpc(saveRPC, { ...payload, p_user_id: userID, p_id: segments[2] }));
        }
        if (request.method === "DELETE") {
            const body = await readBody(request);
            if (Object.keys(body).some(key => key !== "revision")) throw new APIError(400, "Invalid delete fields.");
            return json(await rpc("wif_travel_delete", { p_user_id:userID,p_id:segments[2],p_revision:requiredInteger(body,"revision") }));
        }
    }

    // Trip RPCs are service-role-only and enforce membership internally as well.
    // Actor identity ALWAYS comes from authorize(), never body.userID or a legacy PIN.
    if (request.method === "GET" && path === "/v1/trip-invitations") {
        return json({ invitations: await rpc("wif_trip_invitation_list", { p_user_id: userID }) });
    }
    if (request.method === "POST" && segments.length === 4 && segments[0] === "v1"
        && segments[1] === "trip-invitations" && ["decline", "revoke"].includes(segments[3])) {
        if (!isUUID(segments[2])) throw new APIError(400, "Invalid invitation ID.");
        return json({ success: await rpc("wif_trip_dismiss_invitation", {
            p_user_id: userID, p_invitation_id: segments[2], p_revoke: segments[3] === "revoke",
        }) });
    }
    if (request.method === "POST" && segments.length === 4 && segments[0] === "v1"
        && segments[1] === "trip-invitations" && segments[3] === "accept") {
        if (!isUUID(segments[2])) throw new APIError(400, "Invalid invitation ID.");
        return json(await rpc("wif_trip_accept_invitation", { p_user_id: userID, p_invitation_id: segments[2] }));
    }
    if (request.method === "GET" && path === "/v1/trips") {
        return json({ trips: await rpc("wif_trip_list", { p_user_id: userID }) });
    }
    if (request.method === "POST" && path === "/v1/trips") {
        const body = await readBody(request);
        const tripID = requiredString(body, "id");
        if (!/^[A-Za-z0-9_-]{1,100}$/.test(tripID)) throw new APIError(400, "Invalid trip ID.");
        return json(await rpc("wif_trip_create", {
            p_user_id: userID, p_trip_id: tripID,
            p_name: requiredString(body, "name"),
            p_destination: requiredString(body, "destinationAirport").trim().toUpperCase(),
            p_start: requiredString(body, "startDate"), p_end: requiredString(body, "endDate"),
        }));
    }
    if (segments[0] === "v1" && segments[1] === "trips" && segments.length >= 3) {
        const tripID = segments[2];
        if (!/^[A-Za-z0-9_-]{1,100}$/.test(tripID)) throw new APIError(400, "Invalid trip ID.");
        if (request.method === "POST" && segments.length === 4 && segments[3] === "lifecycle") {
            const body = await readBody(request);
            const action = requiredString(body, "action");
            if (!["leave", "cancel", "delete", "removeMember"].includes(action)
                || Object.keys(body).some(key => !["action", "requestID", "revision", "participantID"].includes(key))
                || !isUUID(body.requestID)
                || (action === "removeMember" ? !isUUID(body.participantID) : body.participantID !== undefined)
                || (action !== "leave" && (!Number.isSafeInteger(body.revision) || (body.revision as number) < 1))
                || (action === "leave" && body.revision !== undefined)) {
                throw new APIError(400, "Invalid trip lifecycle fields.");
            }
            return json(await rpc("wif_trip_lifecycle", { p_user_id: userID, p_trip_id: tripID,
                p_action: action, p_request_id: body.requestID, p_revision: body.revision ?? null,
                p_participant_id: body.participantID ?? null }));
        }
        if (request.method === "POST" && segments.length === 4 && ["preferences", "meeting", "check-in"].includes(segments[3])) {
            const body = await readBody(request);
            const fields: Record<string, string[]> = { preferences:["enabled"], meeting:["point","revision"], "check-in":["state"] };
            if (Object.keys(body).some(key => !fields[segments[3]].includes(key))) throw new APIError(400,"Invalid trip fields.");
            if (segments[3] === "preferences") return json(await rpc("wif_trip_preferences", {
                p_user_id:userID, p_trip_id:tripID, p_enabled:requiredBoolean(body,"enabled"),
            }));
            if (segments[3] === "check-in") return json(await rpc("wif_trip_check_in", {
                p_user_id:userID, p_trip_id:tripID, p_state:requiredString(body,"state"),
            }));
            if (typeof body.point!=="string" || body.point.length>300 || !Number.isSafeInteger(body.revision) || (body.revision as number)<1)
                throw new APIError(400,"A meeting point and current revision are required.");
            return json(await rpc("wif_trip_meeting", {p_user_id:userID,p_trip_id:tripID,p_point:body.point,p_revision:body.revision}));
        }
        if (request.method === "GET" && segments.length === 4 && segments[3] === "invitations") {
            return json({ invitations: await rpc("wif_trip_invitation_list", { p_user_id: userID, p_trip_id: tripID }) });
        }
        if (request.method === "POST" && segments.length === 4 && segments[3] === "mutations") {
            const body = await readBody(request);
            const kind = requiredString(body, "kind");
            const allowed: Record<string, string[]> = {
                details: ["name", "destinationAirport", "startDate", "endDate"], completion: ["completed"],
                addFlight: ["id", "flightNumber", "date", "direction", "candidateID"],
                editFlight: ["id", "flightNumber", "date", "direction", "candidateID"], deleteFlight: ["id"],
            };
            if (!Object.hasOwn(allowed, kind) || !body.payload || typeof body.payload !== "object" || Array.isArray(body.payload)
                || Object.keys(body).some(key => !["kind", "payload", "revision"].includes(key))
                || Object.keys(body.payload).some(key => !allowed[kind].includes(key))) {
                throw new APIError(400, "Invalid trip mutation. Traveler identity and provider data cannot be supplied.");
            }
            if (kind !== "addFlight" && (!Number.isSafeInteger(body.revision) || (body.revision as number) < 1)) {
                throw new APIError(400, "A current revision is required.");
            }
            return json(await rpc("wif_trip_mutate", { p_user_id: userID, p_trip_id: tripID, p_kind: kind,
                p_body: body.payload, p_revision: body.revision ?? null }));
        }
        if (request.method === "POST" && segments.length === 4 && segments[3] === "flight-lookup") {
            try {
                const body = await readBody(request);
                if (Object.keys(body).some(key => !["flightNumber", "date"].includes(key))) {
                    throw new APIError(400, "Only flight number and departure date are accepted.");
                }
                const input = flightLookupInput(body.flightNumber, body.date);
                const reservation = await rpc("wif_trip_flight_lookup_begin", {
                    p_user_id: userID, p_trip_id: tripID, p_number: input.flightNumber, p_date: input.date,
                }) as { cached: unknown };
                if (reservation.cached) return json(reservation.cached);
                const result = await fetchFlightLookup(input, Deno.env.get("RAPIDAPI_KEY"));
                await rpc("wif_trip_flight_lookup_cache", { p_number: input.flightNumber, p_date: input.date, p_result: result });
                return json(result);
            } catch (error) {
                if (error instanceof FlightLookupError) throw new APIError(error.status, error.message);
                throw error;
            }
        }
        if (request.method === "GET" && segments.length === 3) {
            return json(await rpc("wif_trip_snapshot", { p_user_id: userID, p_trip_id: tripID }));
        }
        if (request.method === "PATCH" && segments.length === 3) {
            const body = await readBody(request);
            return json(await rpc("wif_trip_update", {
                p_user_id: userID, p_trip_id: tripID,
                p_name: requiredString(body, "name"),
                p_destination: requiredString(body, "destinationAirport").trim().toUpperCase(),
                p_start: requiredString(body, "startDate"), p_end: requiredString(body, "endDate"),
            }));
        }
        if (request.method === "PUT" && segments.length === 4 && segments[3] === "completion") {
            const body = await readBody(request);
            return json(await rpc("wif_trip_complete", {
                p_user_id: userID, p_trip_id: tripID, p_completed: requiredBoolean(body, "completed"),
            }));
        }
        if (request.method === "POST" && segments.length === 4 && segments[3] === "participants") {
            throw new APIError(403, "Members must sign in and accept an invitation. Guest entry is not supported.");
        }
        if (request.method === "POST" && segments.length === 4 && segments[3] === "invitations") {
            const body = await readBody(request);
            const invitation = await rpc("wif_trip_invite", {
                p_user_id: userID, p_trip_id: tripID, p_username: requiredString(body, "username"),
            });
            wakeInvitations();
            return json(invitation);
        }
        if (segments[3] === "flights" && ((request.method === "POST" && segments.length === 4)
            || (request.method === "PATCH" && segments.length === 5))) {
            const body = await readBody(request);
            const allowed = request.method === "POST" ? ["id", "flightNumber", "date", "direction"] : ["flightNumber", "date", "direction"];
            if (Object.keys(body).some(key => !allowed.includes(key))) {
                throw new APIError(400, "Only your own flight details can be submitted. Do not supply a traveler or account ID.");
            }
            return json(await rpc(request.method === "POST" ? "wif_trip_add_flight" : "wif_trip_update_flight", {
                p_user_id: userID, p_trip_id: tripID,
                p_flight_id: request.method === "POST" ? requiredString(body, "id") : segments[4],
                p_flight_number: requiredString(body, "flightNumber"),
                p_date: requiredString(body, "date"), p_direction: requiredString(body, "direction"),
            }));
        }
        if (request.method === "DELETE" && segments.length === 5 && segments[3] === "flights") {
            return json(await rpc("wif_trip_delete_flight", {
                p_user_id: userID, p_trip_id: tripID, p_flight_id: segments[4],
            }));
        }
    }

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
        const snapshot = await rpc("wif_send_friend_request", {
            p_user_id: userID,
            p_username: requiredString(body, "username"),
        });
        wakeInvitations();
        return json(snapshot);
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
        let administrativeArea: string | null;
        try { administrativeArea = presenceAdministrativeArea(body); }
        catch { throw new APIError(400, "Invalid administrative area."); }
        return json(await rpc("wif_update_presence_v2", {
            p_user_id: userID,
            p_city: requiredString(body, "city"),
            p_country_code: requiredString(body, "countryCode"),
            p_source: requiredString(body, "source"),
            p_client_updated_at: clientUpdatedAt,
            p_administrative_area: administrativeArea,
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
        const push = pushConfiguration(body);

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
        wakeInvitations();
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
