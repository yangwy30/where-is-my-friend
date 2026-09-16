import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import { importPKCS8, SignJWT } from "npm:jose@6.2.8";
import { classifyAPNsResponse, decryptAPNSToken } from "../_shared/push-security.mjs";
import { refreshOneFlight, deliverTripUpdates } from "../_shared/trip-worker.mjs";

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { autoRefreshToken: false, persistSession: false },
});
const secret = Deno.env.get("PUSH_WORKER_SECRET");
const encryptionKey = Deno.env.get("APNS_DEVICE_TOKEN_KEY");
const keyID = Deno.env.get("APNS_KEY_ID");
const teamID = Deno.env.get("APNS_TEAM_ID");
const privateKey = Deno.env.get("APNS_PRIVATE_KEY")?.replaceAll("\\n", "\n");
let cachedToken: { value: string; created: number } | undefined;
async function rpc(name: string, args: Record<string, unknown>) {
    const { data, error } = await db.rpc(name, args);
    if (error) throw new Error(`Trip worker operation failed: ${name}`);
    return data;
}
async function send(delivery: Record<string, string>) {
    const now = Math.floor(Date.now() / 1000);
    if (!cachedToken || now-cachedToken.created>3000) {
        const key = await importPKCS8(privateKey!, "ES256");
        cachedToken = { created: now, value: await new SignJWT({}).setProtectedHeader({alg:"ES256",kid:keyID!})
            .setIssuer(teamID!).setIssuedAt(now).sign(key) };
    }
    const deviceToken = await decryptAPNSToken(delivery.encrypted_apns_token, encryptionKey!);
    const host = delivery.environment === "sandbox" ? "https://api.sandbox.push.apple.com" : "https://api.push.apple.com";
    const response = await fetch(`${host}/3/device/${deviceToken}`, {
        method: "POST", signal: AbortSignal.timeout(10000),
        headers: { authorization:`bearer ${cachedToken.value}`, "apns-topic":delivery.bundle_id,
            "apns-push-type":"alert", "apns-priority":"10", "apns-expiration":"0",
            "apns-collapse-id":delivery.event_id, "content-type":"application/json" },
        body:JSON.stringify({aps:{alert:{title:delivery.title,body:delivery.body},sound:"default","thread-id":"trip-flights"},
            deepLink:delivery.deep_link,eventID:delivery.event_id}),
    });
    const error = response.ok ? {} : await response.json().catch(()=>({}));
    return classifyAPNsResponse(response.status,error.reason ?? "");
}
const json = (value: unknown, status=200) => new Response(JSON.stringify(value), {
    status, headers:{"Content-Type":"application/json","Cache-Control":"no-store"},
});
Deno.serve(async request => {
    if (request.method!=="POST") return json({message:"Method not allowed."},405);
    if (!secret || request.headers.get("Authorization")!==`Bearer ${secret}`) return json({message:"Authentication required."},401);
    try {
        const refresh = await refreshOneFlight(rpc,Deno.env.get("RAPIDAPI_KEY"));
        const push = encryptionKey && keyID && teamID && privateKey
            ? await deliverTripUpdates(rpc,send) : {state:"not_configured"};
        return json({refresh,push});
    } catch { return json({message:"Trip update worker could not complete. Retry is safe."},500); }
});
