const { chromium } = require('playwright');
(async()=>{
  const browser=await chromium.launch({headless:true, args:['--no-sandbox']});
  const context=await browser.newContext({storageState:'/tmp/plaky_storage.json'});
  const page=await context.newPage();
  const reqs=[];
  page.on('request', r=>{ reqs.push({method:r.method(), url:r.url()}); if(r.method()==='POST') console.log('REQ POST', r.url().slice(0,180), r.postData()?.slice(0,400)||''); });
  page.on('response', async r=>{ if(r.request().method()==='POST') console.log('RES POST', r.status(), r.url().slice(0,120)); });
  await page.goto('https://deepiri-crew.plaky.com/', {waitUntil:'networkidle'});
  await page.waitForTimeout(3000);
  // Open invite modal
  await page.evaluate(()=>{
    const btns = Array.from(document.querySelectorAll('button'));
    const b = btns.find(x=> x.textContent.includes('Invite new members'));
    if(b) b.click();
  });
  await page.waitForTimeout(2000);
  await page.fill('input[placeholder*="email" i]', 'jrb00013wvu@gmail.com');
  await page.keyboard.press('Enter');
  await page.waitForTimeout(1000);
  console.log('before Invite click, reqs', reqs.length);
  reqs.length=0;
  await page.evaluate(()=>{
    const btns = Array.from(document.querySelectorAll('button'));
    const b = btns.find(x=> x.textContent.trim()==='Invite' && !x.disabled);
    console.log('Invite btn found', !!b, b?.textContent, b?.disabled);
    if(b) b.click();
  });
  await page.waitForTimeout(10000);
  console.log('after Invite click, reqs', reqs.length);
  for(const r of reqs){
    console.log(r.method, r.url.slice(0,150));
  }
  await browser.close();
})();
