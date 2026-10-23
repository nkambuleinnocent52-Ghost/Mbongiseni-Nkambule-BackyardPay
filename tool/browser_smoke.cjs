// Run against an already served web build. Uses fictional demo data in a fresh browser context.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs=require('node:fs');
const evidence=process.env.EVIDENCE_DIR || '/tmp/backyardpay-evidence';
fs.mkdirSync(evidence,{recursive:true});
let activePage, activeBrowser;
(async () => {
  const browser = await chromium.launch({executablePath:process.env.CHROME_BIN || '/usr/bin/chromium',
    headless:true,args:['--no-sandbox']});
  activeBrowser=browser;
  const context = await browser.newContext({viewport:{width:1440,height:1000},
    acceptDownloads:true,geolocation:{latitude:-33.0153,longitude:27.9116},permissions:['geolocation']});
  const page = await context.newPage();
  activePage=page;
  const errors = [];
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{ if(m.type()==='error') errors.push(m.text()); });
  const activate = async () => {
    const placeholder=page.locator('flt-semantics-placeholder');
    await placeholder.waitFor({state:'attached',timeout:30000});
    await placeholder.evaluate(e=>e.click());
    await page.getByRole('button',{name:'GET STARTED',exact:true}).waitFor();
  };
  const button = async name => {
    console.log('Click',name);
    const b=page.getByRole('button',{name,exact:true});
    for (let i=0;i<16;i++) {
      const box=await b.count() ? await b.first().boundingBox().catch(()=>null) : null;
      if(box && box.y>=0 && box.y+box.height<=1000) break;
      await page.mouse.move(1050,700);
      await page.mouse.wheel(0,box && box.y<0 ? -650 : 650);
      await page.waitForTimeout(150);
    }
    await b.first().click();
    await page.mouse.move(380,820);
    await page.waitForTimeout(450);
  };
  const text = async expected => {
    const target = expected === 'PENDING' || expected === 'CONFIRMED' ? new RegExp('^'+expected+'$') : expected;
    await page.getByText(target,{exact:false}).first().waitFor({timeout:30000});
  };
  const login = async (role,email) => {
    await button('GET STARTED');await button(role);
    await page.getByRole('textbox',{name:'Email',exact:true}).click();
    await page.waitForTimeout(150);
    await page.keyboard.type(email);
    await page.getByRole('textbox',{name:'Password',exact:true}).click();
    await page.waitForTimeout(150);
    await page.keyboard.type('DemoPass123!');
    await button('Login');
    try { await text(role === 'TENANT' ? 'Tenant dashboard' : 'Landlord dashboard'); } catch (e) { console.log('Login screen', await page.locator('body').innerText()); console.log('Errors',errors); await page.screenshot({path:'/tmp/backyardpay-login-failure.png'}); throw e; }
  };
  const logout = async () => {
    await button('Profile');await button('Logout');await button('GET STARTED');
    // Return to splash so the login helper starts from the same place each time.
    await button('Back');
  };
  await page.goto(process.env.APP_URL || 'http://127.0.0.1:8080/');await activate();
  await page.screenshot({path:evidence+'/01-splash.png'});
  await button('Try with demo accounts');
  await text('Demo accounts created. Use the details shown below.');
  await login('TENANT','tenant@demo.test');
  await button('Record payment');
  // Keep the prefilled full monthly rent; amount validation/partial payments have separate domain tests.
  await button('Submit payment');
  await text('PENDING');
  await page.screenshot({path:evidence+'/02-pending-payment.png'});
  assert.equal(await page.getByRole('button',{name:'Download / share receipt',exact:true}).count(),0);
  await button('Back to dashboard');await logout();
  await login('LANDLORD','landlord@demo.test');await button('Payment records');
  await page.getByText('Demo Tenant • R 1500.00',{exact:false}).click();
  await page.screenshot({path:evidence+'/03-landlord-review.png'});
  await button('Confirm payment');await button('Confirm received');await text('CONFIRMED');
  await button('Back to dashboard');
  await page.waitForFunction(() => document.body.innerText.includes('Outstanding: R 0.00'));
  await button('My tenants');
  await page.getByText('Demo Tenant',{exact:false}).click();
  await button('Send rent reminder');await button('Send reminder');
  await button('Back');await button('Back');
  await button('My properties');await page.getByText('BackyardPay Demo Rooms',{exact:false}).click();
  await button('Capture current location');await text('Save this property location?');
  await button('Save location');
  await page.waitForFunction(() => {
    const key=Object.keys(localStorage).find(k=>k.endsWith('backyardpay_v1'));
    if(!key) return false;
    const saved=JSON.parse(localStorage.getItem(key));
    const data=typeof saved === 'string' ? JSON.parse(saved) : saved;
    return data.properties.some(p=>p.latitude === -33.0153 && p.longitude === 27.9116);
  });
  await page.screenshot({path:evidence+'/04-simulated-location.png'});
  await button('Back');await button('Back');await logout();
  await login('TENANT','tenant@demo.test');
  await button('Notifications (2)');
  await page.waitForFunction(() => [...document.querySelectorAll('[aria-label]')].some(e => (e.getAttribute('aria-label') || '').includes('Payment confirmed')));
  await page.screenshot({path:evidence+'/05-notifications.png'});
  assert.match(await page.evaluate(() => [...document.querySelectorAll('[aria-label]')].map(e => e.getAttribute('aria-label')).join(' ')),/Rent reminder/);
  await button('Mark as read');
  await button('Back');await button('Payment history');
  await page.getByText('Demo Tenant • R 1500.00',{exact:false}).click();
  await text('CONFIRMED');
  const downloaded=page.waitForEvent('download');
  await button('Download / share receipt');
  const download=await downloaded;
  assert.match(download.suggestedFilename(),/\.pdf$/);
  const bytes=fs.readFileSync(await download.path());
  assert.equal(bytes.subarray(0,4).toString(),'%PDF');
  fs.writeFileSync(evidence+'/confirmed-receipt.pdf',bytes);
  await button('Back to dashboard');
  await button('Rental details');
  await button('Monthly rental account');
  const statementEvent=page.waitForEvent('download');
  await button('Download account statement');
  const statement=await statementEvent;
  const statementBytes=fs.readFileSync(await statement.path());
  assert.equal(statementBytes.subarray(0,4).toString(),'%PDF');
  fs.writeFileSync(evidence+'/monthly-account.pdf',statementBytes);
  await button('Back');await button('Back');
  await page.reload();
  const placeholder=page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({state:'attached'});await placeholder.evaluate(e=>e.click());
  await text('Tenant dashboard');await page.waitForFunction(() => document.body.innerText.includes('Outstanding: R 0.00'));
  await page.screenshot({path:process.env.SCREENSHOT_PATH || evidence+'/06-tenant-dashboard.png'});
  assert.deepEqual(errors,[]);
  console.log('Browser smoke passed: account switching, payment approval, reminder, simulated geolocation, PDF download and persistence at 1440px.');
  await browser.close();
})().catch(async e=>{ console.error(e); if(activePage) { console.log('Failure screen',await activePage.locator('body').innerText()); await activePage.screenshot({path:'/tmp/backyardpay-smoke-failure.png'}); } if(activeBrowser) await activeBrowser.close(); process.exit(1); });
