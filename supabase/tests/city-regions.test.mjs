import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir, access } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import { cityRegionCatalog as catalog, resolveCityRegion, normalizeRegionText, presenceAdministrativeArea } from '../functions/_shared/city-regions.mjs';

test('one catalog covers reviewed cities, exact state aliases, cross-state groups and safe unknowns', async () => {
    assert.equal(catalog.regionMatchingEnabled, false);
    assert.equal(catalog.schemaVersion, 1);
    const members = new Set(), ids = new Set();
    for (const region of catalog.regions) {
        assert(!ids.has(region.id)); ids.add(region.id);
        assert(region.sourceURLs.length > 0);
        assert(region.scopeNote.length > 0);
        for (const member of region.members) for (const city of member.cities) {
            const key = [region.countryCode, member.administrativeArea, city].map(normalizeRegionText).join('|');
            assert(!members.has(key), `Duplicate geography: ${key}`); members.add(key);
            for (const administrativeArea of [member.administrativeArea, ...member.administrativeAliases]) {
                assert.equal(resolveCityRegion({city, countryCode: region.countryCode, administrativeArea})?.id, region.id);
            }
        }
    }
    for (const input of [
        {city:'Pasadena',countryCode:'US',administrativeArea:'TX'},
        {city:'Santa Clara',countryCode:'US',administrativeArea:'UT'},
        {city:'Sunnyvale',countryCode:'US',administrativeArea:'TX'},
        {city:'Milpitas',countryCode:'US'},
        {city:'Milpitas',administrativeArea:'CA'},
        {city:'Milpitas',countryCode:'CA',administrativeArea:'CA'},
        {city:'Irvine',countryCode:'US',administrativeArea:'CA'},
        {city:'la',countryCode:'US',administrativeArea:'CA'},
    ]) assert.equal(resolveCityRegion(input), null);
    assert.equal(resolveCityRegion({city:'  Sán   Jose ',countryCode:'us',administrativeArea:'california'})?.id,'us-ca-silicon-valley');
    assert.notEqual(resolveCityRegion({city:'San Francisco',countryCode:'US',administrativeArea:'CA'})?.id,
        resolveCityRegion({city:'Milpitas',countryCode:'US',administrativeArea:'CA'})?.id);
    const input={city:'Milpitas',countryCode:'US',administrativeArea:'CA'};
    assert.equal(resolveCityRegion(input,{...catalog,regions:[catalog.regions[0],catalog.regions[0]]}),null);
    assert.equal(resolveCityRegion(input,{...catalog,schemaVersion:99}),null);
    assert.equal(presenceAdministrativeArea({}),null);
    assert.equal(presenceAdministrativeArea({administrativeArea:' California '}),'California');
    assert.throws(()=>presenceAdministrativeArea({administrativeArea:{}}),/Invalid/);
});

const alice='10000000-0000-0000-0000-000000000001', bob='10000000-0000-0000-0000-000000000002';
async function scalar(db,sql,args=[]) { return Object.values((await db.query(sql,args)).rows[0])[0]; }
test('metadata survives snapshots, respects sharing and timestamps, clears for legacy clients, and never expands notifications',async()=>{
    const db=new PGlite();
    try {
        await db.exec('create schema auth; create table auth.users(id uuid primary key,email text); create role anon; create role authenticated; create role service_role;');
        for(const file of (await readdir(new URL('../migrations/',import.meta.url))).filter(f=>f.endsWith('.sql')).sort())
            await db.exec(await readFile(new URL('../migrations/'+file,import.meta.url),'utf8'));
        await db.exec(await readFile(new URL('../seed.sql',import.meta.url),'utf8'));
        await scalar(db,"select wif_send_friend_request($1,'bob')",[alice]);
        const request=(await scalar(db,'select wif_snapshot($1)',[bob])).friendRequests[0].id;
        await scalar(db,"select wif_respond_friend_request($1,$2,'accept')",[bob,request]);
        const count=await scalar(db,'select count(*)::int from colocation_events');
        const update=(id,city,area,age=0)=>scalar(db,"select wif_update_presence_v2($1,$2,'US','foregroundLocation',now()-make_interval(secs=>$4),$3)",[id,city,area,age]);
        let result=await update(alice,'Milpitas','CA');
        assert.equal(result.currentPresence.administrativeArea,'CA');
        await update(bob,'Sunnyvale','CA');
        result=await scalar(db,'select wif_snapshot($1)',[bob]);
        assert.equal(result.friends[0].city,'Milpitas');
        assert.equal(result.friends[0].administrativeArea,'CA');
        assert.equal(await scalar(db,'select count(*)::int from colocation_events'),count);
        await update(alice,'Old city','NY',60);
        assert.equal((await scalar(db,'select wif_snapshot($1)',[alice])).currentPresence.administrativeArea,'CA');
        await scalar(db,'select wif_set_sharing_preferences($1,false,false,true)',[alice]);
        result=await scalar(db,'select wif_snapshot($1)',[bob]);
        assert.equal(result.friends[0].city,null);
        assert.equal(result.friends[0].administrativeArea,null);
        result=await scalar(db,"select wif_update_presence($1,'Paris','FR','manual',now())",[alice]);
        assert.equal(result.currentPresence.administrativeArea,null);
        await db.exec('set role authenticated');
        await assert.rejects(update(alice,'Milpitas','CA'),/permission denied/);
    } finally { await db.close(); }
});
