const { chromium } = require('playwright');
(async()=>{
  const browser=await chromium.launch({headless:true, args:['--no-sandbox']});
  const context=await browser.newContext({storageState:'/tmp/plaky_storage.json'});
  const page=await context.newPage();
  await page.goto('https://deepiri-crew.plaky.com/', {waitUntil:'networkidle'});
  await page.waitForTimeout(3000);
  // Try to find the correct invite endpoint by inspecting the page's localStorage and then trying to call the invite via the same endpoint that the UI would call after filling email
  const inviteRes = await page.evaluate(async (email)=>{
    const user = JSON.parse(localStorage.getItem('user')||'{}');
    const token = user.accessToken;
    // Try the actual invite endpoint that the UI uses for "Invite new members"
    // From the page's localStorage, the workspaceId is 162001, organization 162001
    // The UI likely does POST to https://deepiri-crew.api.plaky.com/organizations/162001/members/invite or similar
    const endpoints = [
      'https://deepiri-crew.api.plaky.com/organizations/162001/members',
      'https://deepiri-crew.api.plaky.com/users',
      'https://deepiri-crew.api.plaky.com/invitations',
    ];
    const results=[];
    for(const ep of endpoints){
      try{
        const r = await fetch(ep, {method:'POST', headers:{'Content-Type':'application/json', 'Authorization':`Bearer ${token}`}, body: JSON.stringify({email: email}), credentials:'include'});
        const txt = await r.text();
        results.push({ep, status:r.status, text:txt.slice(0,800)});
        if(r.status===200 || r.status===201) break;
      }catch(e){ results.push({ep, error:e.message}); }
    }
    return results;
  }, 'jrb00013wvu@gmail.com');
  console.log(JSON.stringify(inviteRes, null,2));
  await browser.close();
})();
