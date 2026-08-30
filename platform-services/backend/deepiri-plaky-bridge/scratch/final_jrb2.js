const { chromium } = require('playwright');
(async()=>{
  const browser=await chromium.launch({headless:true, args:['--no-sandbox']});
  const context=await browser.newContext({storageState:'/tmp/plaky_storage.json'});
  const page=await context.newPage();
  await page.goto('https://deepiri-crew.plaky.com/', {waitUntil:'networkidle'});
  await page.waitForTimeout(3000);
  // Open invite modal
  await page.evaluate(()=>{
    const btns = Array.from(document.querySelectorAll('button'));
    const b = btns.find(x=> x.textContent.includes('Invite new members'));
    if(b) b.click();
  });
  await page.waitForTimeout(2000);
  const inviteInput = page.locator('input[placeholder*="email" i]').last();
  await inviteInput.fill('jrb00013wvu@gmail.com');
  await inviteInput.press('Enter');
  await page.waitForTimeout(1000);
  // Click Invite
  await page.evaluate(()=>{
    const btns = Array.from(document.querySelectorAll('button'));
    const b = btns.find(x=> x.textContent.trim()==='Invite' && !x.disabled);
    if(b) b.click();
  });
  console.log('clicked Invite');
  await page.waitForTimeout(8000);
  console.log('done');
  await browser.close();
})();
