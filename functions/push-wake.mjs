import {dispatchPush} from '../push-core.mjs';
export default async req=>{
 if(req.method!=='POST')return new Response('Method not allowed',{status:405});
 const authorization=req.headers.get('authorization');if(!authorization?.startsWith('Bearer '))return new Response('Sign in required',{status:401});
 const r=await fetch(Netlify.env.get('VR_SUPABASE_URL')+'/auth/v1/user',{headers:{apikey:Netlify.env.get('VR_SUPABASE_PUBLIC_KEY'),Authorization:authorization},signal:AbortSignal.timeout(6000)});
 if(!r.ok)return new Response('Sign in required',{status:401});
 try{await dispatchPush();return Response.json({ok:true},{headers:{'Cache-Control':'no-store'}})}catch{return Response.json({ok:false},{status:503})}
};
export const config={method:'POST',rateLimit:{action:'rate_limit',aggregateBy:'ip',windowSize:60,windowLimit:15}};
