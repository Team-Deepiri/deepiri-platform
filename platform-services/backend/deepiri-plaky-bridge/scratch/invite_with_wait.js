const { chromium } = require('playwright');
(async()=>{
  const browser=await chromium.launch({headless:true, args:['--no-sandbox']});
  const context=await browser.newContext({storageState:'/tmp/plaky_storage.json'});
  const page=await context.newPage();
  const reqs=[];
  page.on('request', r=>{ reqs.push({method:r.method(), url:r.url()}); if(r.method()==='POST' && r.url().includes('plaky')) console.log('REQ POST', r.url().slice(0,150)); });
  await page.goto('https://deepiri-crew.plaky.com/', {waitUntil:'networkidle'});
  await page.waitForTimeout(3000);
  await page.evaluate(()=>{
    const btns = Array.from(document.querySelectorAll('button'));
    const b = btns.find(x=> x.textContent.includes('Invite new members'));
    if(b) b.click();
  });
  await page.waitForTimeout(2000);
  await page.fill('input[placeholder*="email" i]', 'jrb00013wvu@gmail.com');
  await page.keyboard.press('Enter');
  await page.waitForTimeout(1000);
  reqs.length=0;
  await page.evaluate(()=>{
    const btns = Array.from(document.querySelectorAll('button'));
    const b = btns.find(x=> x.textContent.trim()==='Invite' && !x.disabled);
    if(b) b.click();
  });
  console.log('clicked Invite, waiting 60s');
  await page.waitForTimeout(60000);
  console.log('after wait, reqs', reqs.length);
  for(const r of reqs){
    console.log(r.method, r.url.slice(0,150));
  }
  await browser.close();
})();
