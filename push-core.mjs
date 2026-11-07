import webpush from 'web-push';
export function isPushEndpoint(value){try{const u=new URL(value);return u.protocol==='https:'&&!u.port&&!u.username&&!u.password&&['fcm.googleapis.com','updates.push.services.mozilla.com','web.push.apple.com'].some(h=>u.hostname===h||u.hostname.endsWith('.'+h))||(()=>{const u=new URL(value);return u.protocol==='https:'&&!u.port&&!u.username&&!u.password&&(u.hostname.endsWith('.notify.windows.com')||u.hostname.endsWith('.push.apple.com')||u.hostname.endsWith('.push.services.mozilla.com'))})()}catch{return false}}
export async function dispatchPush(env=Netlify.env){
 const url=env.get('VR_SUPABASE_URL'),key=env.get('VR_SUPABASE_PUBLIC_KEY'),token=env.get('VR_PUSH_WORKER_TOKEN');
 if(!url||!key||!token||!env.get('VR_VAPID_PRIVATE_KEY')){console.info(JSON.stringify({event:'push_dispatch_skipped',configured:false}));return 0;}
 webpush.setVapidDetails('https://vendarides.netlify.app',env.get('VR_VAPID_PUBLIC_KEY'),env.get('VR_VAPID_PRIVATE_KEY'));
 async function rpc(name,data){const r=await fetch(url+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:JSON.stringify({...data,p_token:token}),signal:AbortSignal.timeout(8000)});if(!r.ok)throw new Error('Push queue operation failed');return r.json()}
 const pending=await rpc('claim_ride_push',{});let delivered=0;
 await Promise.all(pending.map(async n=>{let sent=false;const expired=[];await Promise.all((n.subscriptions||[]).map(async s=>{if(!isPushEndpoint(s.endpoint)){expired.push(s.id);return}try{await webpush.sendNotification({endpoint:s.endpoint,keys:s.keys},JSON.stringify({title:n.title,body:n.body,url:'/#account',tag:n.id}),{TTL:300,timeout:6000});sent=true}catch(e){if(e.statusCode===404||e.statusCode===410)expired.push(s.id)}}));await rpc('settle_ride_push',{p_id:n.id,p_sent:sent,p_expired:expired});if(sent)delivered++}));
 console.info(JSON.stringify({event:'push_dispatch_complete',configured:true,notifications:delivered}));return delivered;
}
