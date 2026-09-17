// Recheck itinerary, membership, preferences, expiry and device ownership before each send.
export async function deliverTripBookingReminders(database, token, send) {
 const claimed=await database.rpc('wif_trip_booking_claim',{p_token:token});
 if(claimed.error)throw new Error('Trip reminder queue unavailable.');
 const outcomes=[];
 for(let offset=0;offset<(claimed.data??[]).length;offset+=3) {
  outcomes.push(...await Promise.all(claimed.data.slice(offset,offset+3).map(async row=>{
   const prepared=await database.rpc('wif_trip_booking_prepare',{p_id:row.delivery_id,p_token:token});
   if(prepared.error)return 'retry';
   if(!prepared.data) {
    const released=await database.rpc('wif_trip_booking_complete',{p_id:row.delivery_id,p_token:token,p_outcome:'failed'});
    if(released.error)throw new Error('Could not release invalid trip reminder.');
    return 'failed';
   }
   return send({...prepared.data,kind:'trip-reminder'});
  })));
 }
 return outcomes;
}
