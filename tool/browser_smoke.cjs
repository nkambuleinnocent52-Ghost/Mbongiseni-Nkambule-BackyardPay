// Flutter browser/API contract test with an isolated simulated Supabase transport.
// No real Supabase project is contacted or seeded. Server authorization is tested
// separately against PostgreSQL by tool/test_database.sh.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const crypto=require('node:crypto');
const dir=process.env.EVIDENCE_DIR || '/tmp/backyardpay-cloud-evidence';fs.mkdirSync(dir,{recursive:true});
const users=[], properties=[], tenancies=[], payments=[], notices=[], cases=[], depositPaymentReports=[];
const now=()=>new Date().toISOString();
const jwt=u=>`${Buffer.from('{"alg":"HS256"}').toString('base64url')}.${Buffer.from(JSON.stringify({sub:u.id,exp:Math.floor(Date.now()/1000)+3600})).toString('base64url')}.test-only`;
const session=u=>({access_token:jwt(u),refresh_token:u.id,token_type:'bearer',expires_in:3600,user:{id:u.id,email:u.email,role:'authenticated',aud:'authenticated',app_metadata:{provider:'email'},user_metadata:{},created_at:now()}});
const snapshot=u=>{
 const ps=properties.filter(p=>p.landlordId===u.id || tenancies.some(t=>t.userId===u.id && t.propertyId===p.id));
 const ts=tenancies.filter(t=>t.userId===u.id || ps.some(p=>p.id===t.propertyId && p.landlordId===u.id));
 const ids=new Set([u.id,...ts.map(t=>t.userId),...ps.map(p=>p.landlordId)]);
 return {version:1,researchVersion:2,prorationVersion:1,depositReportsVersion:1,advanceRentVersion:1,depositPaymentsVersion:1,depositRemindersVersion:1,depositReminderScheduler:false,depositPaymentReports:depositPaymentReports.filter(r=>ts.some(t=>t.id===r.tenancyId)),rentTerms:ts.map(t=>({tenancyId:t.id,period:t.startPeriod,amountCents:t.rentCents,dueDay:t.dueDay})),caseRecords:cases.filter(r=>ts.some(t=>t.id===r.tenancyId)),session:u.id,accounts:users.filter(a=>ids.has(a.id)).map(({password,...a})=>a),properties:ps,tenancies:ts,payments:payments.filter(p=>ts.some(t=>t.id===p.tenancyId)),notices:notices.filter(n=>n.userId===u.id)};
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
   if(path.endsWith('/bp_tenant_signup_mode'))return reply('invitation_only');
   if(path.endsWith('/signup')){
    const u={id:crypto.randomUUID(),email:body.email,password:body.password,...body.data,salt:'',passwordHash:''};users.push(u);
    if(u.role==='tenant'){
     const t=tenancies.find(t=>t.invitation===u.code);assert(t);assert.equal(t.userId,'');assert(!('room' in body.data));
     t.userId=u.id;t.invitation='USED-'+crypto.randomUUID();
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
     result=crypto.randomUUID();properties.push({...a,id:result,landlordId:u.id,roomRents:{},code:'BP-CONTRACT-TEST',latitude:null,longitude:null});
    } else if(body.operation==='room_rents'){const p=properties.find(p=>p.id===a.propertyId);p.roomRents=a.rates;result=p.id;
    } else if(body.operation==='property_message'){result=1;notices.push({id:crypto.randomUUID(),userId:tenancies[0].userId,title:'Property update',message:a.message,createdAt:now(),read:false});
    } else if(body.operation==='deposit_deadline'){const t=tenancies.find(t=>t.id===a.tenancyId);assert(t);assert.equal(properties.find(p=>p.id===t.propertyId).landlordId,u.id);t.record.depositDueOn=a.date;t.record.depositDueNote=a.note;result=t.id;
    } else if(body.operation==='deposit_update'){result=a.eventId;cases.push({id:result,tenancyId:a.tenancyId,kind:'deposit',body:a.body,actor:u.id,createdAt:now()});
    } else if(body.operation==='deposit_report'){
     const t=tenancies.find(t=>t.id===a.tenancyId);assert(t&&t.userId===u.id,'Tenant may report only their own deposit');
     const existing=depositPaymentReports.find(r=>r.id===a.eventId);result=a.eventId;
     if(!existing){depositPaymentReports.push({...a,id:result,state:'pending',reason:'',submittedAt:now(),reviewedAt:null});notices.push({id:crypto.randomUUID(),userId:properties.find(p=>p.id===t.propertyId).landlordId,title:'Deposit payment reported',message:'Check this tenant deposit payment',createdAt:now(),read:false});}
    } else if(body.operation==='deposit_review'){
     const r=depositPaymentReports.find(r=>r.id===a.id);assert(r);const t=tenancies.find(t=>t.id===r.tenancyId);assert.equal(properties.find(p=>p.id===t.propertyId).landlordId,u.id,'Only landlord can confirm a deposit');result=r.id;
     if(r.state==='pending'){r.state=a.confirm?'confirmed':'rejected';r.reason=a.reason||'';r.reviewedAt=now();if(a.confirm)cases.push({id:r.id,tenancyId:r.tenancyId,kind:'deposit',body:{event:'received',amountCents:r.amountCents,date:r.paidOn,method:r.method,reference:r.reference,bankReference:r.bankReference,payer:r.payer,note:'Tenant deposit payment confirmed by landlord'},actor:u.id,createdAt:now()});notices.push({id:crypto.randomUUID(),userId:t.userId,title:a.confirm?'Deposit payment confirmed':'Deposit payment not confirmed',message:r.reason||'Your deposit payment has been checked',createdAt:now(),read:false});}
    } else if(body.operation==='tenancy'){
     const p=properties.find(p=>p.id===a.propertyId);assert(p);result=crypto.randomUUID();
     tenancies.push({id:result,userId:'',propertyId:p.id,room:String(a.room),startPeriod:a.start.slice(0,7),rentCents:p.roomRents[String(a.room)]??p.rentCents,dueDay:p.dueDay,ledgerVersion:2,depositCents:p.securityDepositCents,depositReceivedCents:0,invitation:'JOIN-'+crypto.randomUUID().replaceAll('-','').toUpperCase(),record:{firstMonthProration:p.prorateFirstMonth?'actual_days':'full_month',tenancyStartedOn:a.start}});
    } else if(body.operation==='payment'){
     result=crypto.randomUUID();payments.push({...a,id:result,period:a.paidOn.slice(0,7),state:'pending',submittedAt:now()});
    } else if(body.operation==='review'){
     const p=payments.find(p=>p.id===a.id);assert(p);result=p.id;p.state=a.confirm?'confirmed':'rejected';p.reviewedAt=now();if(a.allocations)p.allocations=a.allocations;p.receiptDetails={tenant:'Tenant Test',landlord:'Owner Test',landlordAddress:'1 Owner Street',property:'My Real Rooms',address:'1 Test Street, Southernwood, East London, 5201',room:'1',issuedAllocations:p.allocations,issuedCreditCents:0};
     const t=tenancies.find(t=>t.id===p.tenancyId);notices.push({id:crypto.randomUUID(),userId:t.userId,title:'Payment confirmed',message:'Receipt available',createdAt:now(),read:false});
    } else if(body.operation==='case'){result=a.eventId;cases.push({id:result,tenancyId:a.tenancyId,kind:a.kind,body:{...a.body,...(['repair','query'].includes(a.kind)?{status:'open'}:{})},actor:u.id,createdAt:now()});
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
 const expand=async(page,name)=>{await page.getByRole('button',{name:new RegExp(name)}).first().evaluate(e=>e.click());await page.waitForTimeout(350);};
 const choose=async(page,label,value)=>{
  await page.getByRole('button',{name:new RegExp(label)}).first().evaluate(e=>e.click());await page.waitForTimeout(200);
  await page.getByRole('menuitem',{name:value,exact:true}).evaluate(e=>e.click());await page.waitForTimeout(350);
 };
 const semantics=async page=>(await page.locator('body').innerText())+'\n'+(await page.locator('[aria-label]').evaluateAll(es=>es.map(e=>e.getAttribute('aria-label')||'').join('\n')));
 const reveal=async(page,target)=>{for(let i=0;i<16;i++){const b=await target.count()?await target.boundingBox():null;if(b&&b.y>=0&&b.y+b.height<=1000)break;await page.mouse.move(1050,700);await page.mouse.wheel(0,b&&b.y<0?-650:650);await page.waitForTimeout(120);}};
 const confirmRent=async(page)=>{
  await button(page,'Confirm payment');const confirmation=page.getByRole('checkbox');
  for(let i=0;i<12;i++){const b=await confirmation.boundingBox();if(b&&b.y>0&&b.y+b.height<950)break;await page.mouse.move(1050,700);await page.mouse.wheel(0,400);await page.waitForTimeout(150);}
  await confirmation.click();await button(page,'Confirm received');await page.getByText(/^CONFIRMED$/).first().waitFor();
 };
 const register=async(page,role,email)=>{
  await button(page,'GET STARTED');await button(page,role);await button(page,'Create an account');
  await fill(page,'Full name',role==='LANDLORD'?'Owner Test':'Tenant Test');await fill(page,'Phone number','0711234567');await fill(page,'Email',email);await fill(page,'Password','TestPassword123!');await fill(page,'Confirm password','TestPassword123!');
  if(role==='TENANT'){assert.equal(await page.getByRole('textbox',{name:'Room number',exact:true}).count(),0);await fill(page,'Private invitation from your landlord',tenancies[0].invitation);}
  await button(page,'Create account');await page.getByText(role==='LANDLORD'?'Landlord dashboard':'Tenant dashboard',{exact:true}).waitFor();
 };
 const owner=await make();assert(!((await owner.locator('body').innerText()).toLowerCase().includes('demo')));
 await register(owner,'LANDLORD','owner@contract.test');await button(owner,'My properties');await button(owner,'Add property');
 for(const [name,value] of [['Property name','My Real Rooms'],['Street address / stand number','1 Test Street'],['Suburb / area','Southernwood'],['Town / city','East London'],['Postal code (4 digits)','5201'],['Total rooms','2'],['Security deposit per new tenancy (rand; 0 if none)','2000']])await fill(owner,name,value);
 await button(owner,'Save');await owner.getByText('My Real Rooms',{exact:false}).waitFor();await owner.getByText('My Real Rooms',{exact:false}).first().evaluate(e=>e.click());await owner.waitForTimeout(350);
 await expand(owner,'Room rent');await owner.getByRole('checkbox',{name:'Room 1',exact:true}).evaluate(e=>e.click());await fill(owner,'Monthly rent for selected rooms (rand)','1800');await button(owner,'Save room rent');assert.equal(properties[0].roomRents['1'],180000);await button(owner,'Back');await button(owner,'Back');
 await button(owner,'Add tenant record');await button(owner,'Enter tenant details');await fill(owner,'Tenant full name','Tenant Test');
 const room=owner.getByRole('button',{name:'Available room',exact:true});
 await room.evaluate(e=>e.click());await owner.waitForTimeout(350);
 await owner.getByRole('menuitem',{name:'Room 1',exact:true}).evaluate(e=>e.click());
 await button(owner,'Save');await button(owner,'Back');
 const tenant=await make();await register(tenant,'TENANT','tenant@contract.test');
 const today=new Date(),monthDays=new Date(today.getUTCFullYear(),today.getUTCMonth()+1,0).getUTCDate();const firstCents=Math.round(180000*(monthDays-today.getUTCDate()+1)/monthDays);const paymentLabel=`Tenant Test • R ${(firstCents/100).toFixed(2)}`;
 await button(tenant,'Record payment');assert.equal(await tenant.getByRole('checkbox').count(),0);await tenant.screenshot({path:dir+'/plain-payment-tenant.png'});await button(tenant,'Submit payment');await tenant.getByText(/^PENDING$/).first().waitFor();
 await button(owner,'Refresh records');await button(owner,'My properties');const propertyTile=owner.getByText('My Real Rooms',{exact:false}).first();for(let i=0;i<16;i++){const b=await propertyTile.count()?await propertyTile.boundingBox():null;if(b&&b.y>=0&&b.y+b.height<=1000)break;await owner.mouse.move(1050,700);await owner.mouse.wheel(0,b&&b.y<0?-650:650);await owner.waitForTimeout(120);}await propertyTile.click();await owner.waitForTimeout(350);
 await owner.getByText('Room 1: Unavailable',{exact:false}).first().waitFor();await owner.getByText('Room 2: Available',{exact:false}).first().waitFor();await owner.screenshot({path:dir+'/room-availability.png'});
 await button(owner,'Back');await button(owner,'Back');await button(owner,'Payment records');await owner.getByText(paymentLabel,{exact:false}).click();
 await button(owner,'Confirm payment');await owner.screenshot({path:dir+'/plain-payment-landlord.png'});const cb=owner.getByRole('checkbox');for(let i=0;i<12;i++){const b=await cb.boundingBox();if(b&&b.y>0&&b.y+b.height<950)break;await owner.mouse.move(1050,700);await owner.mouse.wheel(0,400);await owner.waitForTimeout(150);}await cb.click();await button(owner,'Confirm received');await owner.getByText(/^CONFIRMED$/).first().waitFor();
 await button(tenant,'Back to dashboard');await button(tenant,'Refresh records');
 assert((await tenant.locator('body').innerText()).includes('Recorded balance: R 0.00'));
 await button(tenant,'Payment history');await tenant.getByText(paymentLabel,{exact:false}).click();
 const downloadPromise=tenant.waitForEvent('download');await button(tenant,'Download / share receipt');const download=await downloadPromise;
 const bytes=fs.readFileSync(await download.path());assert.equal(bytes.subarray(0,4).toString(),'%PDF');fs.writeFileSync(dir+'/receipt.pdf',bytes);
 await tenant.screenshot({path:dir+'/confirmed-payment.png'});
 await tenant.setViewportSize({width:390,height:844});await tenant.screenshot({path:dir+'/tenant-phone.png'});await tenant.setViewportSize({width:1440,height:1000});
 await tenant.reload();await tenant.locator('flt-semantics-placeholder').waitFor();await tenant.locator('flt-semantics-placeholder').evaluate(e=>e.click());await tenant.getByText('Tenant dashboard',{exact:true}).waitFor();
 assert((await tenant.locator('body').innerText()).includes('Recorded balance: R 0.00'));
 // Paying a later rental month must be available without charging it as current debt.
 const nextDate=new Date(Date.UTC(today.getUTCFullYear(),today.getUTCMonth()+1,1));
 const nextPeriod=nextDate.toISOString().slice(0,7),nextLabel=new Intl.DateTimeFormat('en-GB',{month:'short',year:'numeric',timeZone:'UTC'}).format(nextDate);
 const futurePaymentLabel='Tenant Test • R 1800.00';
 await button(tenant,'Record payment');await choose(tenant,'Month paid for',nextLabel);
 const advanceAmount=tenant.getByRole('textbox',{name:'How much did you pay? (rand)',exact:true});await advanceAmount.click();await tenant.waitForTimeout(150);assert.equal(await advanceAmount.inputValue(),'1800.00');
 await tenant.screenshot({path:dir+'/advance-rent-report.png'});await button(tenant,'Submit payment');
 assert.equal(payments.length,2);assert.equal(payments[1].allocations[0].period,nextPeriod);assert.equal(payments[1].state,'pending');
 await button(owner,'Back to dashboard');await button(owner,'Refresh records');await button(owner,'Payment records');await owner.getByText(futurePaymentLabel,{exact:false}).first().click();await confirmRent(owner);
 assert.equal(payments[1].receiptDetails.issuedAllocations[0].period,nextPeriod);
 await button(tenant,'Back to dashboard');await button(tenant,'Refresh records');
 assert((await tenant.locator('body').innerText()).includes('Recorded balance: R 0.00'),'Advance payment does not change current-month balance');
 await button(tenant,'Payment history');await tenant.getByText(futurePaymentLabel,{exact:false}).first().click();
 const advanceDownloadPromise=tenant.waitForEvent('download');await button(tenant,'Download / share receipt');const advanceDownload=await advanceDownloadPromise;
 const advanceBytes=fs.readFileSync(await advanceDownload.path());assert.equal(advanceBytes.subarray(0,4).toString(),'%PDF');fs.writeFileSync(dir+'/advance-rent-receipt.pdf',advanceBytes);await tenant.screenshot({path:dir+'/advance-rent-confirmed.png'});
 // An agreed deposit deadline ten South African calendar days ago must warn once it is overdue.
 await button(owner,'Back to dashboard');await button(owner,'My tenants');await owner.getByText('Tenant Test',{exact:false}).first().evaluate(e=>e.click());await owner.waitForTimeout(350);
 await expand(owner,'Security deposit');await expand(owner,'Deposit due date and reminder');
 const sastToday=new Date(Date.now()+2*60*60*1000);const depositDueDate=new Date(Date.UTC(sastToday.getUTCFullYear(),sastToday.getUTCMonth(),sastToday.getUTCDate()-10)).toISOString().slice(0,10);
 await fill(owner,'Agreed deposit due date (YYYY-MM-DD)',depositDueDate);await fill(owner,'Reason / agreement for this due date','Agreed deposit date for this isolated reminder test');await button(owner,'Save agreed due date');assert.equal(tenancies[0].record.depositDueOn,depositDueDate);
 await button(owner,'Back');await button(owner,'Back');
 await button(tenant,'Back to dashboard');await button(tenant,'Refresh records');
 const unpaidReminder=tenant.getByRole('button',{name:'Report a deposit payment',exact:true});await reveal(tenant,unpaidReminder);assert.equal(await unpaidReminder.count(),1,'Tenant sees an overdue deposit warning after ten days');assert((await semantics(tenant)).includes('Deposit reminder'));await tenant.screenshot({path:dir+'/deposit-reminder-tenant.png'});
 await button(tenant,'Record payment');await choose(tenant,'Payment for','Security deposit');
 await fill(tenant,'Deposit paid (rand)','2000.00');await choose(tenant,'How was it paid?','EFT');await fill(tenant,'Bank payment reference','TENANT-DEPOSIT-EFT-TEST');
 await tenant.screenshot({path:dir+'/deposit-report-tenant.png'});await button(tenant,'Send deposit payment');
 assert.equal(depositPaymentReports.length,1);assert.equal(depositPaymentReports[0].state,'pending');assert.equal(cases.filter(r=>r.kind==='deposit').length,0,'A tenant report is not a received deposit');
 await button(tenant,'Refresh records');await tenant.mouse.move(1050,700);await tenant.mouse.wheel(0,-5000);await tenant.waitForTimeout(250);
 assert.equal(await tenant.getByRole('button',{name:'Report a deposit payment',exact:true}).count(),0,'Fully reported deposit must not ask tenant to pay again');
 await tenant.screenshot({path:dir+'/deposit-reminder-awaiting-review.png'});
 assert((await semantics(tenant)).includes('Deposit payment waiting for review'));
 assert((await semantics(tenant)).includes('Do not pay that reported amount again'));
 await tenant.screenshot({path:dir+'/deposit-reminder-awaiting-review.png'});
 await button(owner,'Refresh records');await button(owner,'Deposit payments to check (1)');
 await owner.getByRole('checkbox',{name:/I checked that this deposit payment was received/}).evaluate(e=>e.click());await button(owner,'Confirm deposit payment');
 assert.equal(depositPaymentReports[0].state,'confirmed');assert.equal(cases.filter(r=>r.kind==='deposit'&&r.body.event==='received').length,1);await owner.screenshot({path:dir+'/deposit-confirmed-landlord.png'});
 await button(owner,'Back');await button(tenant,'Refresh records');
 await tenant.mouse.move(1050,700);await tenant.mouse.wheel(0,-5000);await tenant.waitForTimeout(250);
 assert((await tenant.locator('body').innerText()).includes('Recorded balance: R 0.00'),'Deposit stays separate from rent balance');
 assert.equal(await tenant.getByRole('button',{name:'Report a deposit payment',exact:true}).count(),0,'Confirmed deposit no longer has a payment reminder');assert(!(await semantics(tenant)).includes('Deposit payment waiting for review'),'Confirmed receipt clears the reminder banner');await tenant.mouse.move(1050,700);await tenant.mouse.wheel(0,-5000);await tenant.waitForTimeout(250);await tenant.screenshot({path:dir+'/deposit-reminder-cleared.png'});
 await button(tenant,'Report a problem / account query');
 await fill(tenant,'Where is the problem?','Outside shared tap');await fill(tenant,'Describe the issue','Water is leaking continuously from the shared tap. Please arrange an inspection.');await button(tenant,'Send issue');
 await button(owner,'Refresh records');await button(owner,'Tenant reports');
 assert(cases.some(r=>r.kind==='repair'));await owner.screenshot({path:dir+'/report-before-ack.png'});fs.writeFileSync(dir+'/report-semantics.json',JSON.stringify(await owner.locator('[role]').evaluateAll(es=>es.map(e=>({role:e.getAttribute('role'),label:e.getAttribute('aria-label'),text:e.innerText}))),null,2));
 await owner.getByRole('checkbox',{name:/Noted by landlord/}).evaluate(e=>e.click());await owner.waitForTimeout(350);
 assert(cases.some(r=>r.kind==='case_update'&&r.body.status==='in_progress'));
 await expand(owner,'Reply / send update');await fill(owner,'Update message','Plumber contacted; agreeing access with the tenant.');await button(owner,'Send update');
 assert.equal(tenancies[0].depositCents,200000);assert.equal(payments.length,2,'Issue and deposit report created no extra rent payment');
 await owner.screenshot({path:dir+'/report-followup.png'});
 await owner.getByRole('switch').evaluate(e=>e.click());await fill(owner,'Update message','Shared pipe repairs are booked for noon.');await button(owner,'Send update');assert(notices.some(n=>n.message==='Shared pipe repairs are booked for noon.'));
 await button(owner,'Mark resolved');assert(cases.some(r=>r.kind==='case_update'&&r.body.status==='resolved'));
 await button(owner,'Back');await button(owner,'My tenants');await owner.getByText('Tenant Test',{exact:false}).first().evaluate(e=>e.click());await owner.waitForTimeout(350);
 assert.equal(await owner.getByRole('button',{name:'Rental documents / supporting files',exact:true}).count(),0);
 await expand(owner,'Security deposit');assert(await owner.getByRole('checkbox',{name:/Deposit received/}).first().isChecked());assert.equal(cases.filter(r=>r.kind==='deposit'&&r.body.event==='received').length,1,'Checking an already confirmed deposit must not record it twice');
 await owner.mouse.move(1050,700);await owner.mouse.wheel(0,-5000);await owner.waitForTimeout(250);await owner.screenshot({path:dir+'/simple-rental-desktop.png'});
 await owner.setViewportSize({width:390,height:844});await owner.screenshot({path:dir+'/simple-rental-phone.png'});await owner.setViewportSize({width:1440,height:1000});

 await button(tenant,'Back');await button(tenant,'Refresh records');await button(tenant,'Report a problem / account query');
 assert(await tenant.getByRole('checkbox',{name:/Noted by landlord/}).isChecked());
 await button(tenant,'Back');await button(tenant,'Profile');await button(tenant,'Logout');await button(tenant,'GET STARTED');await button(tenant,'TENANT');await button(tenant,'Forgot password?');
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
 console.log('Cloud browser/API contract passed: two isolated browser sessions, registration, custom room rates, landlord room assignment, payment approval, future-month rent and receipt, ten-day deposit warning and agreed deadline, pending-only review wording without pay-again warning, tenant deposit report/landlord confirmation clearing reminder, PDF, shared issue acknowledgement, private reply, property broadcast, resolution, inline deposit receipt, compact phone/desktop layout, restored Auth session and password recovery. Transport simulated; hosted email and database activation remain unverified.');
 await browser.close();
})().catch(async e=>{console.error(e);if(browser)await browser.close();process.exit(1);});
