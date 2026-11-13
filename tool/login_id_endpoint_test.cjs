// Isolated Edge Function contract test; no network or live credentials.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const {stripTypeScriptTypes}=require('node:module');
const {webcrypto}=require('node:crypto');
const source=stripTypeScriptTypes(fs.readFileSync('supabase/functions/login-with-id/index.ts','utf8'),{mode:'strip'});
const settings={SUPABASE_URL:'https://isolated.test',SUPABASE_ANON_KEY:'public-test-key',SUPABASE_SERVICE_ROLE_KEY:'server-only-test-key'};
let handler,blocked=false,unknown=false,rejectPassword=false,requests=[];
const sandbox={Request,Response,TextEncoder,crypto:webcrypto,Deno:{env:{get:n=>settings[n]},serve:fn=>handler=fn},fetch:async(url,options)=>{
  const body=JSON.parse(options.body||'{}');requests.push({url,body,headers:options.headers});
  if(url.endsWith('/bp_login_id_enabled'))return Response.json(true);
  if(url.endsWith('/bp_begin_login_id_attempt')){
    assert.equal(options.headers.apikey,settings.SUPABASE_SERVICE_ROLE_KEY);
    assert.match(body.client_hash,/^[a-f0-9]{64}$/);
    assert(!body.client_hash.includes('203.0.113'));
    return Response.json(blocked?{allowed:false}:{allowed:true,email:unknown?null:'private-owner@example.test'});
  }
  if(url.includes('/auth/v1/token'))return rejectPassword||unknown?Response.json({error:'wrong password'},{status:400}):Response.json({access_token:'test-access',refresh_token:'test-refresh'});
  throw new Error('Unexpected destination');
}};
vm.runInNewContext(source,sandbox);
const req=(body,origin='https://quiet-pastelito-19fa50.netlify.app')=>new Request('https://function.test/login-with-id',{method:'POST',headers:{origin,'content-type':'application/json','x-forwarded-for':'203.0.113.4'},body:JSON.stringify(body)});
(async()=>{
 const valid={loginId:'321 654 987',password:'The same password'};
 let response=await handler(req(valid));assert.equal(response.status,200);assert.equal(response.headers.get('cache-control'),'no-store');
 assert.deepEqual(await response.json(),{access_token:'test-access',refresh_token:'test-refresh'});
 const auth=requests.find(r=>r.url.includes('/auth/v1/token'));assert.deepEqual(auth.body,{email:'private-owner@example.test',password:valid.password});
 response=await handler(req(valid,'https://untrusted.test'));assert.equal(response.status,403);assert.equal(response.headers.get('access-control-allow-origin'),null);
 blocked=true;requests=[];response=await handler(req(valid));assert.equal(response.status,400);assert(!requests.some(r=>r.url.includes('/auth/v1/token')));assert(!(await response.text()).includes('private-owner'));
 blocked=false;unknown=true;response=await handler(req(valid));const unknownMessage=await response.text();assert.equal(response.status,400);
 unknown=false;rejectPassword=true;response=await handler(req(valid));assert.equal(await response.text(),unknownMessage);
 response=await handler(req({loginId:'bad',password:'x'}));assert.equal(response.status,400);assert.equal(await response.text(),unknownMessage);
 response=await handler(new Request('https://function.test/login-with-id',{method:'GET',headers:{origin:'https://quiet-pastelito-19fa50.netlify.app'}}));assert.deepEqual(await response.json(),{enabled:true});
 console.log('Login ID endpoint contract passed: same-password Auth verification, private email resolution, generic failures, blocked attempts, no-store responses and CORS. Database atomic limits have separate SQL tests.');
})().catch(e=>{console.error(e);process.exit(1)});
