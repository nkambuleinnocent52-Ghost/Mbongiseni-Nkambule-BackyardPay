// Flutter browser/API contract test with an isolated simulated Supabase transport.
// No real Supabase project is contacted or seeded. Server authorization is tested
// separately against PostgreSQL by tool/test_database.sh.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const crypto=require('node:crypto');
const dir=process.env.EVIDENCE_DIR || '/tmp/backyardpay-cloud-evidence';fs.mkdirSync(dir,{recursive:true});
const users=[], properties=[], tenancies=[], payments=[], notices=[];
const now=()=>new Date().toISOString();
const jwt=u=>`${Buffer.from('{"alg":"HS256"}').toString('base64url')}.${Buffer.from(JSON.stringify({sub:u.id,exp:Math.floor(Date.now()/1000)+3600})).toString('base64url')}.test-only`;
const session=u=>({access_token:jwt(u),refresh_token:u.id,token_type:'bearer',expires_in:3600,user:{id:u.id,email:u.email,role:'authenticated',aud:'authenticated',app_metadata:{provider:'email'},user_metadata:{},created_at:now()}});
const snapshot=u=>{
 const ps=properties.filter(p=>p.landlordId===u.id || tenancies.some(t=>t.userId===u.id && t.propertyId===p.id));
 const ts=tenancies.filter(t=>t.userId===u.id || ps.some(p=>p.id===t.propertyId && p.landlordId===u.id));
 const ids=new Set([u.id,...ts.map(t=>t.userId),...ps.map(p=>p.landlordId)]);
 return {version:1,researchVersion:2,prorationVersion:1,rentTerms:ts.map(t=>({tenancyId:t.id,period:t.startPeriod,amountCents:t.rentCents,dueDay:t.dueDay})),caseRecords:[],session:u.id,accounts:users.filter(a=>ids.has(a.id)).map(({password,...a})=>a),properties:ps,tenancies:ts,payments:payments.filter(p=>ts.some(t=>t.id===p.tenancyId)),notices:notices.filter(n=>n.userId===u.id)};
};
let browser;
let recoveryEmail;
(async()=>{
 browser=await chromium.launch({executablePath:process.env.CHROME_BIN||'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
 const errors=[];
 const make=async()=>{
  const context=await browser.newContext({viewport:{width:1440,height:1000},acceptDownloads:true});
  await context.route('https://zmxxgetndtcyuwzwwjbd.supabase.co/**',async route=>{
   const req=route.request(),path=new URL(req.url()).pathname,body=req.postDataJSON()||{};
   const reply=data=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(data)});
   if(path.endsWith('/signup')){
    const u={id:crypto.randomUUID(),email:body.email,password:body.password,...body.data,salt:'',passwordHash:''};users.push(u);
    if(u.role==='tenant'){
     const p=properties.find(p=>p.code===u.code);assert(p);assert(!tenancies.some(t=>t.propertyId===p.id&&t.room===u.room));
     tenancies.push({id:crypto.randomUUID(),userId:u.id,propertyId:p.id,room:u.room,startPeriod:now().slice(0,7),rentCents:p.rentCents,dueDay:p.dueDay,ledgerVersion:2,record:{firstMonthProration:p.prorateFirstMonth?'actual_days':'full_month',tenancyStartedOn:now().slice(0,10)}});
    }
    return reply(session(u));
   }
   if(path.endsWith('/recover')) { recoveryEmail=body.email;return reply({}); }
   if(path.endsWith('/token')){
    const u=body.auth_code?users.find(u=>u.email===recoveryEmail):body.refresh_token?users.find(u=>u.id===body.refresh_token):users.find(u=>u.email===body.email&&u.password===body.password);assert(u);return reply(session(u));
   }
   if(path.endsWith('/logout'))return reply({});
   const token=req.headers().authorization?.split(' ')[1];
   const id=token?JSON.parse(Buffer.from(token.split('.')[1],'base64url')).sub:null;
   const u=users.find(u=>u.id===id);assert(u,'Authenticated API request required');
   if(path.endsWith('/user')) { if(body.password)u.password=body.password;return reply(session(u).user); }
   if(path.endsWith('/bp_snapshot'))return reply(snapshot(u));
   if(path.endsWith('/bp_action')){
    const a=body.args;let result=null;
    if(body.operation==='property'){
     result=crypto.randomUUID();properties.push({...a,id:result,landlordId:u.id,code:'BP-CONTRACT-TEST',latitude:null,longitude:null});
    } else if(body.operation==='payment'){
     result=crypto.randomUUID();payments.push({...a,id:result,state:'pending',submittedAt:now()});
    } else if(body.operation==='review'){
     const p=payments.find(p=>p.id===a.id);assert(p);result=p.id;p.state=a.confirm?'confirmed':'rejected';p.reviewedAt=now();if(a.allocations)p.allocations=a.allocations;p.receiptDetails={tenant:'Tenant Test',landlord:'Owner Test',landlordAddress:'1 Owner Street',property:'My Real Rooms',address:'1 Test Street, Southernwood, East London, 5201',room:'1',issuedAllocations:p.allocations,issuedCreditCents:0};
     const t=tenancies.find(t=>t.id===p.tenancyId);notices.push({id:crypto.randomUUID(),userId:t.userId,title:'Payment confirmed',message:'Receipt available',createdAt:now(),read:false});
    } else throw Error('Unexpected command: '+body.operation);
    return reply({result});
   }
   throw Error('Unexpected test API route: '+path);
  });
  const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  await page.goto(process.env.APP_URL||'http://127.0.0.1:8080/');await page.locator('flt-semantics-placeholder').waitFor();await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  return page;
 };
 const button=async(page,name)=>{
  console.log('Click',name);const b=page.getByRole('button',{name,exact:true}).first();
  for(let i=0;i<16;i++){
   const box=await b.count()?await b.boundingBox():null;
   if(box&&box.y>=0&&box.y+box.height<=1000)break;
   await page.mouse.move(1050,700);await page.mouse.wheel(0,box&&box.y<0?-650:650);await page.waitForTimeout(120);
  }
  await b.click();await page.mouse.move(1400,980);await page.waitForTimeout(350);
 };
 const fill=async(page,name,value)=>{const field=page.getByRole('textbox',{name,exact:true});await field.click();await page.waitForTimeout(120);await page.keyboard.press('Control+A');await page.keyboard.type(value);};
 const register=async(page,role,email)=>{
  await button(page,'GET STARTED');await button(page,role);await button(page,'Create an account');
  await fill(page,'Full name',role==='LANDLORD'?'Owner Test':'Tenant Test');await fill(page,'Phone number','0711234567');await fill(page,'Email',email);await fill(page,'Password','TestPassword123!');await fill(page,'Confirm password','TestPassword123!');
  if(role==='TENANT'){await fill(page,'Property code or private tenant invitation','BP-CONTRACT-TEST');await fill(page,'Room number','1');}
  await button(page,'Create account');await page.getByText(role==='LANDLORD'?'Landlord dashboard':'Tenant dashboard',{exact:true}).waitFor();
 };
 const owner=await make();assert(!((await owner.locator('body').innerText()).toLowerCase().includes('demo')));
 await register(owner,'LANDLORD','owner@contract.test');await button(owner,'My properties');await button(owner,'Add property');
 for(const [name,value] of [['Property name','My Real Rooms'],['Street address / stand number','1 Test Street'],['Suburb / area','Southernwood'],['Town / city','East London'],['Postal code (4 digits)','5201'],['Total rooms','2']])await fill(owner,name,value);
 await button(owner,'Save');await owner.getByText('My Real Rooms',{exact:false}).waitFor();await button(owner,'Back');
 const tenant=await make();await register(tenant,'TENANT','tenant@contract.test');
 const today=new Date(),monthDays=new Date(today.getUTCFullYear(),today.getUTCMonth()+1,0).getUTCDate();const firstCents=Math.round(150000*(monthDays-today.getUTCDate()+1)/monthDays);const paymentLabel=`Tenant Test • R ${(firstCents/100).toFixed(2)}`;
 await button(tenant,'Record payment');await button(tenant,'Submit payment');await tenant.getByText(/^PENDING$/).first().waitFor();
 await button(owner,'Refresh records');await button(owner,'Payment records');await owner.getByText(paymentLabel,{exact:false}).click();
 await button(owner,'Confirm payment');const cb=owner.getByRole('checkbox');for(let i=0;i<12;i++){const b=await cb.boundingBox();if(b&&b.y>0&&b.y+b.height<950)break;await owner.mouse.move(1050,700);await owner.mouse.wheel(0,400);await owner.waitForTimeout(150);}await cb.click();await button(owner,'Confirm received');await owner.getByText(/^CONFIRMED$/).first().waitFor();
 await button(tenant,'Back to dashboard');await button(tenant,'Refresh records');
 assert((await tenant.locator('body').innerText()).includes('Recorded balance: R 0.00'));
 await button(tenant,'Payment history');await tenant.getByText(paymentLabel,{exact:false}).click();
 const downloadPromise=tenant.waitForEvent('download');await button(tenant,'Download / share receipt');const download=await downloadPromise;
 const bytes=fs.readFileSync(await download.path());assert.equal(bytes.subarray(0,4).toString(),'%PDF');fs.writeFileSync(dir+'/receipt.pdf',bytes);
 await tenant.screenshot({path:dir+'/confirmed-payment.png'});
 await tenant.setViewportSize({width:390,height:844});await tenant.screenshot({path:dir+'/tenant-phone.png'});await tenant.setViewportSize({width:1440,height:1000});
 await tenant.reload();await tenant.locator('flt-semantics-placeholder').waitFor();await tenant.locator('flt-semantics-placeholder').evaluate(e=>e.click());await tenant.getByText('Tenant dashboard',{exact:true}).waitFor();
 assert((await tenant.locator('body').innerText()).includes('Recorded balance: R 0.00'));
 await button(tenant,'Profile');await button(tenant,'Logout');await button(tenant,'GET STARTED');await button(tenant,'TENANT');await button(tenant,'Forgot password?');
 await fill(tenant,'Email','tenant@contract.test');await button(tenant,'Send reset link');
 assert.equal(recoveryEmail,'tenant@contract.test');
 await tenant.goto((process.env.APP_URL||'http://127.0.0.1:8080/')+'?code=test-only-recovery');
 await tenant.locator('flt-semantics-placeholder').waitFor();await tenant.locator('flt-semantics-placeholder').evaluate(e=>e.click());
 await tenant.getByText('Choose your new password',{exact:true}).waitFor();
 await fill(tenant,'New password','ReplacementPass123!');await fill(tenant,'Confirm new password','ReplacementPass123!');await button(tenant,'Save password and sign in');
 assert(!tenant.url().includes('code='),'One-use auth code removed from URL');
 await tenant.reload();await tenant.locator('flt-semantics-placeholder').waitFor();await tenant.locator('flt-semantics-placeholder').evaluate(e=>e.click());
 await button(tenant,'GET STARTED');await button(tenant,'TENANT');await fill(tenant,'Email','tenant@contract.test');await fill(tenant,'Password','ReplacementPass123!');await button(tenant,'Login');await tenant.getByText('Tenant dashboard',{exact:true}).waitFor();
 assert.deepEqual(errors,[]);assert.equal(users.length,2);assert.equal(payments[0].state,'confirmed');
 console.log('Cloud browser/API contract passed: two isolated browser sessions, registration, property, tenant allocation, payment approval, refresh, PDF, restored Auth session, password recovery callback and reload. Transport simulated; hosted email and database activation remain unverified.');
 await browser.close();
})().catch(async e=>{console.error(e);if(browser)await browser.close();process.exit(1);});
