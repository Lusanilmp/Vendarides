const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const source=fs.readFileSync(require('node:path').join(__dirname,'JavaScript.js'),'utf8').replace(/^import .*;\n/gm,'');
async function boot(url,{session=null,sessionError=null,loginError=null}={}){
  const nodes=new Map(),events={},calls={signOut:[],signUp:[],login:[],reset:[],getUser:0};
  function node(id){if(!nodes.has(id)){const classes=new Set();nodes.set(id,{innerHTML:'',textContent:'',value:'',classList:{add:x=>classes.add(x),remove:x=>classes.delete(x),toggle:(x,v)=>v?classes.add(x):classes.delete(x),contains:x=>classes.has(x)},addEventListener(){},insertAdjacentHTML(_where,html){this.innerHTML+=html},showModal(){this.open=true},close(){this.open=false},querySelectorAll(){return []},dataset:{}})}return nodes.get(id)}
  let current=new URL(url),authListener;
  const location={get href(){return current.href},get hash(){return current.hash},set hash(v){current.hash=v},get origin(){return current.origin}};
  const storage=new Map([['vr-auth-redirect','1']]);
  const query=new Proxy({}, {get(_t,key){if(key==='then')return resolve=>Promise.resolve(resolve({data:[],error:null}));if(key==='maybeSingle')return async()=>({data:{first_name:'Test'},error:null});return ()=>query}});
  const db={auth:{onAuthStateChange(fn){authListener=fn},async getSession(){authListener?.('SIGNED_IN');current.hash='';return {data:{session},error:sessionError}},async getUser(){calls.getUser++;return {data:{user:session?.user??null}}},async signOut(opts){calls.signOut.push(opts);session=null;authListener?.('SIGNED_OUT');return {error:null}},async signUp(v){calls.signUp.push(v);return {data:{user:{id:'test'},session:null},error:null}},async signInWithPassword(v){calls.login.push(v);if(loginError)return {data:{},error:loginError};session={user:{id:'test',email_confirmed_at:'2026-11-07'}};return {data:session,error:null}},async resetPasswordForEmail(email,opts){calls.reset.push({email,...opts});return {error:null}}},from(){return query},channel(){return {on(){return this},subscribe(){}}}};
  const context=vm.createContext({URL,URLSearchParams,Date,console:{warn(){},error(){}},CONFIGURED:true,SUPABASE_URL:'https://example.supabase.co',SUPABASE_PUBLISHABLE_KEY:'public',initCommunity:()=>({searchRides:async()=>[],bookings(){},people(){},requests(){},profileMedia:async()=>{},alerts(){},nav(){},wake(){}}),matchMedia:()=>({matches:false}),createClient:()=>db,location,history:{replaceState(_s,_t,url){current=new URL(url,current)}},sessionStorage:{getItem:k=>storage.get(k),setItem:(k,v)=>storage.set(k,v),removeItem:k=>storage.delete(k)},document:{querySelector:node,querySelectorAll:()=>[],body:node('body')},window:{addEventListener:(e,fn)=>events[e]=fn,dispatchEvent(){},scrollTo(){}},navigator:{},Event:class{},FormData:class{constructor(f){return Object.entries(f.values)[Symbol.iterator]()}},clearTimeout(){},setTimeout(fn,ms){if(ms===0)return setImmediate(fn);return 1}});
  vm.runInContext(source,context);
  const flush=async()=>{for(let i=0;i<5;i++)await new Promise(setImmediate)};
  await flush();
  return {context,node,calls,location,storage,flush,db,run:code=>vm.runInContext(code,context)};
}
const confirmed={user:{id:'test',email_confirmed_at:'2026-11-07'}};
test('confirmation returns to existing sign-in, clears tokens, and signs out locally',async()=>{
  const b=await boot('https://vendarides.netlify.app/?auth=confirm#access_token=test&refresh_token=test&type=signup',{session:confirmed});
  assert.equal(b.calls.signOut.length,1);assert.equal(b.calls.signOut[0].scope,'local');
  assert.equal(b.location.href,'https://vendarides.netlify.app/#home');
  assert.equal(b.node('#modal').open,true);assert.match(b.node('#authForm').innerHTML,/Email confirmed/);
  assert.match(b.node('#authForm').innerHTML,/current-password/);assert.equal(b.calls.getUser,0);
  assert.equal(b.storage.has('vr-auth-redirect'),false);
});
test('old links falling back to Site URL also return to sign-in',async()=>{
  const b=await boot('https://vendarides.netlify.app/#access_token=test&type=signup',{session:confirmed});
  assert.match(b.node('#authForm').innerHTML,/Email confirmed/);assert.equal(b.location.hash,'#home');
});
for(const url of ['https://vendarides.netlify.app/?auth=confirm#error=access_denied&error_code=otp_expired&error_description=Expired','https://vendarides.netlify.app/?auth=confirm','https://vendarides.netlify.app/#error=access_denied&error_code=otp_expired']){
  test('invalid or expired callback shows sign-in without claiming confirmation: '+url,async()=>{
    const b=await boot(url);assert.match(b.node('#authForm').innerHTML,/invalid or has expired/);assert.doesNotMatch(b.location.href,/error|auth=|token/);assert.equal(b.calls.signOut.length,0);
  });
}
test('an invalid session is never reported as confirmed',async()=>{
  const b=await boot('https://vendarides.netlify.app/?auth=confirm#access_token=test&type=signup',{sessionError:new Error('Invalid token')});
  assert.match(b.node('#authForm').innerHTML,/invalid or has expired/);assert.equal(b.calls.signOut.length,0);
});
test('normal signed-in visits still open dashboard',async()=>{
  const b=await boot('https://vendarides.netlify.app/',{session:confirmed});assert.equal(b.location.hash,'#account');assert.equal(b.calls.signOut.length,0);
});
test('password recovery is not treated as signup confirmation',async()=>{
  const b=await boot('https://vendarides.netlify.app/#access_token=test&type=recovery',{session:confirmed});assert.equal(b.calls.signOut.length,0);assert.equal(b.run('emailConfirmationReturn'),false);
});
test('signup explicitly requests the production confirmation URL and preserves profile fields',async()=>{
  const b=await boot('https://vendarides.netlify.app/');b.run('showAuth();authForm(true)');
  await b.node('#actualAuth').onsubmit({preventDefault(){},target:{values:{email:'test@example.com',password:'test-only-password',first_name:'Test',surname:'Rider',phone:'+27000000000',home_area:'Sibasa'}}});
  const signup=b.calls.signUp[0];assert.equal(signup.options.emailRedirectTo,'https://vendarides.netlify.app/?auth=confirm');assert.equal(signup.options.data.home_area,'Sibasa');assert.equal(b.location.hash,'');
});
test('successful password sign-in still opens account',async()=>{
  const b=await boot('https://vendarides.netlify.app/');b.run('showAuth()');
  await b.node('#actualAuth').onsubmit({preventDefault(){},target:{values:{email:'test@example.com',password:'test-only-password'}}});
  assert.equal(b.calls.login.length,1);assert.equal(b.location.hash,'#account');assert.equal(b.node('#modal').open,false);
});
test('failed password sign-in leaves the form available',async()=>{
  const b=await boot('https://vendarides.netlify.app/',{loginError:new Error('Invalid login credentials')});b.run('showAuth()');
  await b.node('#actualAuth').onsubmit({preventDefault(){},target:{values:{email:'test@example.com',password:'test-only-password'}}});
  assert.equal(b.node('#modal').open,true);assert.equal(b.location.hash,'');assert.equal(b.node('#toast').textContent,'Invalid login credentials');
});
test('password reset keeps its existing return route',async()=>{
  const b=await boot('https://vendarides.netlify.app/');b.run('showAuth()');b.node('#actualAuth [name=email]').value='test@example.com';await b.node('#resetPass').onclick();assert.equal(b.calls.reset[0].redirectTo,'https://vendarides.netlify.app/#account');
});
