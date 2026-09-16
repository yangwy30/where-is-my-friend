import test from 'node:test';
import assert from 'node:assert/strict';
import {flightLookupInput,normalizeFlightResults,fetchFlightLookup} from '../functions/_shared/flight-lookup.mjs';
const input=flightLookupInput('ua 353','2026-09-06');
const fixture={number:'UA 353',status:'Arrived',airline:{name:'United'},
    departure:{airport:{iata:'EWR'},scheduledTime:{local:'2026-09-06 18:30-04:00',utc:'2026-09-06 22:30Z'},revisedTime:{local:'2026-09-06 19:00-04:00'}},
    arrival:{airport:{iata:'LAX'},scheduledTime:{local:'2026-09-06 21:33-07:00'},runwayTime:{local:'2026-09-06 21:40-07:00'}}};
test('lookup preserves schedule/revised/runway times, overnight dates and multiple routes without invented status',()=>{
    const other={...fixture,status:'Undocumented',arrival:{...fixture.arrival,airport:{iata:'SFO'}}};
    const yesterday={...fixture,departure:{...fixture.departure,scheduledTime:{local:'2026-09-05 23:30-04:00'}}};
    const result=normalizeFlightResults([fixture,fixture,other,yesterday],input);
    assert.equal(result.flights.length,2);
    assert.equal(result.flights[0].status,'landed');
    assert.equal(result.flights[0].departure.revisedTime.local,'2026-09-06 19:00-04:00');
    assert.equal(result.flights[0].arrival.runwayTime.local,'2026-09-06 21:40-07:00');
    assert.equal(result.flights[1].status,'unknown');
    assert.equal(result.flights[0].arrival.revisedTime.local,null);
    assert.throws(()=>flightLookupInput('../secrets','2026-09-06'));
    assert.throws(()=>flightLookupInput('UA353','2026-02-30'));
});
test('lookup sends server credential only to fixed provider host with departure-date filtering',async()=>{
    const result=await fetchFlightLookup(input,'fixture-key',async(url,options)=>{
        assert.equal(url.origin,'https://aerodatabox.p.rapidapi.com');
        assert.equal(url.pathname,'/flights/number/UA353/2026-09-06');
        assert.equal(url.searchParams.get('dateLocalRole'),'Departure');
        assert.equal(options.headers['X-RapidAPI-Key'],'fixture-key');
        return new Response(JSON.stringify([fixture]));
    });
    assert.equal(result.source,'aerodatabox');
    assert.equal(JSON.stringify(result).includes('fixture-key'),false);
});
test('provider failures never become mock flights or leak provider bodies',async()=>{
    for(const status of [401,402,403,429,500]) {
        await assert.rejects(fetchFlightLookup(input,'fixture-key',async()=>new Response('private-provider-details',{status})),e=>{
            assert.equal(e.message.includes('private-provider-details'),false);
            assert.ok([502,503].includes(e.status)); return true;
        });
    }
    assert.deepEqual((await fetchFlightLookup(input,'fixture-key',async()=>new Response(null,{status:204}))).flights,[]);
    assert.deepEqual((await fetchFlightLookup(input,'fixture-key',async()=>new Response(null,{status:404}))).flights,[]);
    await assert.rejects(fetchFlightLookup(input,''),e=>e.status===503);
    await assert.rejects(fetchFlightLookup(input,'fixture-key',async()=>{throw new Error('secret');}),e=>e.status===502&&!e.message.includes('secret'));
    await assert.rejects(fetchFlightLookup(input,'fixture-key',async()=>new Response('{}')),e=>e.status===502);
});
