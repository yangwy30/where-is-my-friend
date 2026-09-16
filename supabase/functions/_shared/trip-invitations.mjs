// Lease IDs only. Resolve account-bound invitation and device ownership again at send time.
export async function deliverTripInvitations(database, token, send) {
    const {data,error}=await database.rpc('wif_trip_invitation_claim',{p_token:token});
    if(error) throw new Error('Trip invitation queue unavailable.');
    const outcomes=[];
    async function deliver(row) {
        const prepared=await database.rpc('wif_trip_invitation_prepare',{p_id:row.delivery_id,p_token:token});
        if(prepared.error) return 'retry';
        if(!prepared.data) {
            const completed=await database.rpc('wif_trip_invitation_complete',{
                p_id:row.delivery_id,p_token:token,p_outcome:'failed',p_error:'Invitation no longer available.'});
            if(completed.error) throw new Error('Could not release invalid invitation.');
            return 'failed';
        }
        return send({...prepared.data,kind:'trip-invitation'});
    }
    for(let start=0;start<(data??[]).length;start+=5) {
        outcomes.push(...await Promise.all(data.slice(start,start+5).map(deliver)));
    }
    return outcomes;
}
