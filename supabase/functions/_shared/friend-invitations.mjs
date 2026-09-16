// Claims contain identifiers only; re-check the request and device owner at send time.
export async function deliverFriendInvitations(database, token, send) {
    const {data,error}=await database.rpc('wif_friend_invitation_claim',{p_token:token});
    if(error) throw new Error('Friend invitation queue unavailable.');
    const outcomes=[];
    async function deliver(row) {
        const prepared=await database.rpc('wif_friend_invitation_prepare',{p_id:row.delivery_id,p_token:token});
        if(prepared.error) return 'retry'; // The lease expires so the next worker can retry safely.
        if(!prepared.data) {
            const completed=await database.rpc('wif_friend_invitation_complete',{
                p_id:row.delivery_id,p_token:token,p_outcome:'failed',p_error:'Friend request no longer available.'});
            if(completed.error) throw new Error('Could not release invalid friend request.');
            return 'failed';
        }
        return send({...prepared.data,kind:'friend-invitation'});
    }
    for(let start=0;start<(data??[]).length;start+=3) {
        outcomes.push(...await Promise.all(data.slice(start,start+3).map(deliver)));
    }
    return outcomes;
}
