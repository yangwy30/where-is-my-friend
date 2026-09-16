const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function normalizeAPNsPrivateKey(value) {
    let key = (value ?? '').trim();
    if ((key.startsWith('"') && key.endsWith('"')) || (key.startsWith("'") && key.endsWith("'"))) key = key.slice(1,-1);
    key = key.replaceAll('\\r\\n','\n').replaceAll('\\n','\n').trim();
    if (/^LS0tLS1CRUdJTi/.test(key)) {
        try { key = atob(key).trim(); } catch { /* invalid input remains invalid */ }
    }
    return key;
}
export function travelPlanInput(body) {
    const fields=['city','countryCode','region','timeZone','startDay','endDay','audience','alertsEnabled','revision','allowFriendBrowsing'];
    if(!body || typeof body!=='object' || Array.isArray(body) || Object.keys(body).some(k=>!fields.includes(k))) throw new TypeError('Invalid travel plan fields.');
    for(const field of ['city','countryCode','timeZone','startDay','endDay']) {
        if(typeof body[field]!=='string'||!body[field].trim()) throw new TypeError(`Missing ${field}.`);
    }
    if(typeof body.region!=='string'||body.region.length>120||body.city.length>120||!/^[A-Z]{2}$/.test(body.countryCode)
      || !Number.isInteger(body.revision)||body.revision<0||typeof body.alertsEnabled!=='boolean'
      ||!Array.isArray(body.audience)||body.audience.length>100||body.audience.some(x=>typeof x!=='string'||!uuid.test(x))) throw new TypeError('Invalid travel plan.');
    for(const field of ['startDay','endDay']) {
        const d=body[field];
        if(!/^\d{4}-\d{2}-\d{2}$/.test(d)||!Number.isFinite(Date.parse(d))||new Date(d).toISOString().slice(0,10)!==d) throw new TypeError('Invalid calendar date.');
    }
    if(body.endDay<body.startDay) throw new TypeError('End date must not precede start date.');
    const hasBrowsingConsent=Object.hasOwn(body,'allowFriendBrowsing');
    if(hasBrowsingConsent && typeof body.allowFriendBrowsing!=='boolean') throw new TypeError('Invalid plan visibility.');
    return {p_city:body.city.trim(),p_country:body.countryCode,p_region:body.region.trim(),p_time_zone:body.timeZone,
        p_start:body.startDay,p_end:body.endDay,p_audience:[...new Set(body.audience)],p_alerts:body.alertsEnabled,p_revision:body.revision,
        ...(hasBrowsingConsent?{p_allow_friend_browsing:body.allowFriendBrowsing}:{})};
}

// Only IDs are leased. Access, device ownership and current overlap are checked
// again immediately before sending; removed consent never uses queued text.
export async function deliverUpcoming(database, token, send) {
    const {data, error}=await database.rpc('wif_travel_claim',{p_token:token});
    if(error) throw new Error('Upcoming reminder queue unavailable.');
    const results=[];
    for(const row of data??[]) {
        const prepared=await database.rpc('wif_travel_prepare',{p_id:row.delivery_id,p_token:token});
        if(prepared.error) { results.push('retry'); continue; }
        if(!prepared.data) {
            await database.rpc('wif_travel_complete',{p_id:row.delivery_id,p_token:token,p_outcome:'failed',p_disable_device:false});
            results.push('failed'); continue;
        }
        results.push(await send({...prepared.data,kind:'upcoming'}));
    }
    return results;
}
