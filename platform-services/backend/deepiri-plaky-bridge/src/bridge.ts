import { chromium, Browser, BrowserContext, Page } from 'playwright';
import fs from 'fs/promises';
import path from 'path';
import axios from 'axios';
import { fetchPlakyCode } from './emailCodeProvider';

const PLAKY_API_BASE = process.env.PLAKY_API_BASE || 'https://api.plaky.com/v1/public';
const PLAKY_API_KEY = process.env.PLAKY_API_KEY || process.env.PLAKY_API_TOKEN || '';
const PLAKY_EMAIL = process.env.PLAKY_EMAIL || process.env.PLAKY_BOT_EMAIL || process.env.IMAP_USER || '';
const PLAKY_PASSWORD = process.env.PLAKY_PASSWORD || '';
const IMAP_USER = process.env.IMAP_USER || PLAKY_EMAIL;
const IMAP_PASS = process.env.IMAP_PASS || '';

// Cake Account layer — Deepiri is migrated to CAKE.com account. Invites flow
// through the Cake members API which is captcha-free and SSO-cookie-authenticated.
// Verified live: POST /api/organizations/{org}/workspaces/invitations/new-users
// with a plain Sso-Token cookie returns `{"failedInvitations":{}}` — no
// Cloudflare Turnstile / reCAPTCHA involved (Plaky's /users/invitation is
// hard captcha-gated and cannot be automated).
const CAKE_API_BASE = process.env.CAKE_API_BASE || 'https://account.cake.com/api';
const CAKE_ORGANIZATION_ID = process.env.CAKE_ORGANIZATION_ID || '691e10dd4d0f05010229ceda';
const CAKE_WORKSPACE_IDS = (process.env.CAKE_WORKSPACE_IDS || '691e10dd4d0f05010229cede').split(',').filter(Boolean);

export type InviteResult = {
  success: boolean;
  email: string;
  role?: string;
  status?: string;
  error?: string;
  via: 'api' | 'browser' | 'cake' | 'check-only';
};

export class PlakyBridge {
  private browser: Browser | null = null;
  private context: BrowserContext | null = null;
  private page: Page | null = null;
  private sessionPath: string;
  isReady = false;
  private refreshTimer: NodeJS.Timeout | null = null;

  constructor() {
    const dataDir = process.env.PLAKY_BRIDGE_DATA_DIR || path.join(__dirname, '..', 'data');
    this.sessionPath = path.join(dataDir, 'session.json');
  }

  async init() {
    // Always validate real API first — it's the source of truth for membership checks
    if (PLAKY_API_KEY) {
      try {
        const r = await axios.get(`${PLAKY_API_BASE}/users/me`, {
          headers: { 'X-API-Key': PLAKY_API_KEY },
          timeout: 8000,
        });
        console.log(`[PlakyBridge] Real API OK as ${r.data?.email} (${r.data?.type})`);
      } catch (e: any) {
        console.warn(`[PlakyBridge] Real API check failed: ${e.message}`);
      }
    }

    if (!PLAKY_EMAIL) {
      console.warn('[PlakyBridge] PLAKY_EMAIL/PLAKY_BOT_EMAIL not set — browser automation disabled. Real API read-only mode.');
      this.isReady = true; // still ready for read-only checks
      return;
    }
    if (!IMAP_PASS) {
      console.warn('[PlakyBridge] IMAP_PASS not set — code auto-retrieval disabled. Will try session reuse only; if expired, login will fail until IMAP configured.');
    }

    try {
      const dataDir = path.dirname(this.sessionPath);
      await fs.mkdir(dataDir, { recursive: true });

      this.browser = await chromium.launch({
        headless: true, // 100% background, no GUI
        args: ['--disable-dev-shm-usage', '--disable-gpu', '--no-sandbox', '--disable-setuid-sandbox', '--disable-blink-features=AutomationControlled'],
      });
      this.context = await this.browser.newContext({
        viewport: { width: 1920, height: 1080 },
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      });
      this.page = await this.context.newPage();

      const restored = await this.loadSession();
      if (!restored) await this.login();

      this.isReady = true;
      console.log('[PlakyBridge] Browser ready (headless)');
      this.startSessionRefresh();
    } catch (e) {
      console.error('[PlakyBridge] init failed', e);
      throw e;
    }
  }

  private async saveSession() {
    if (!this.context) return;
    const cookies = await this.context.cookies();
    await fs.writeFile(this.sessionPath, JSON.stringify(cookies, null, 2));
  }

  private async loadSession(): Promise<boolean> {
    try {
      const raw = await fs.readFile(this.sessionPath, 'utf8');
      const cookies = JSON.parse(raw);
      if (!this.context || !this.page) return false;
      await this.context.addCookies(cookies);
      await this.page.goto('https://deepiri-crew.plaky.com/dashboard', { waitUntil: 'networkidle', timeout: 15000 });
      // If we still see workspace UI, session is valid
      await this.page.waitForSelector('body', { timeout: 5000 });
      // Cheap check: not on login page
      if (this.page.url().includes('/login')) return false;
      console.log('[PlakyBridge] Session restored');
      return true;
    } catch {
      console.log('[PlakyBridge] No valid session, will login');
      return false;
    }
  }

  private async login() {
    if (!this.page || !PLAKY_EMAIL) throw new Error('Missing browser/page or PLAKY_EMAIL');
    console.log(`[PlakyBridge] Logging in headless as ${PLAKY_EMAIL} (code flow)...`);
    await this.page.goto('https://deepiri-crew.plaky.com/login', { waitUntil: 'networkidle', timeout: 20000 });

    // Step 1: fill email and request code — handle Cloudflare Turnstile
    const emailSels = ['input[placeholder*="email" i]', '#email', 'input[type="email"]', 'input[name="email"]', '[data-testid="email"]'];
    let filled = false;
    for (const s of emailSels) {
      try { await this.page.fill(s, PLAKY_EMAIL, { timeout: 5000 }); filled = true; break; } catch {}
    }
    if (!filled) throw new Error('Could not find email input');

    // Wait for Turnstile token (cf-turnstile-response) to be populated — without it Plaky won't send code
    try {
      await this.page.waitForFunction(() => {
        const el = (globalThis as any).document.querySelector('input[name="cf-turnstile-response"]');
        return el && el.value && el.value.length > 10;
      }, { timeout: 15000 });
      console.log('[PlakyBridge] Turnstile solved');
    } catch {
      console.log('[PlakyBridge] Turnstile not solved in 15s, proceeding anyway');
    }
    await this.page.waitForTimeout(1000);

    const continueSels = ['button:has-text("Continue with email")', 'button:has-text("Continue")', '#login-btn', 'button[type="submit"]', 'button:has-text("Log in")'];
    let clicked = false;
    for (const s of continueSels) {
      try { await this.page.click(s, { timeout: 5000 }); clicked = true; break; } catch {}
    }
    if (!clicked) throw new Error('Could not click Continue');
    await this.page.waitForTimeout(2500);
    await this.page.waitForLoadState('networkidle', { timeout: 12000 }).catch(() => {});

    // If password field appears, it's old flow — try it
    const hasPassword = await this.page.locator('input[type="password"]').first().isVisible().catch(() => false);
    if (hasPassword && PLAKY_PASSWORD) {
      await this.page.fill('input[type="password"]', PLAKY_PASSWORD).catch(() => {});
      for (const s of ['button:has-text("Log in")', 'button[type="submit"]']) {
        try { await this.page.click(s, { timeout: 3000 }); break; } catch {}
      }
      await this.page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
      await this.page.waitForTimeout(2000);
      if (!this.page.url().includes('/login')) {
        await this.saveSession();
        console.log('[PlakyBridge] Login success via password');
        return;
      }
    }

    // Step 2: code flow — fetch code from IMAP
    if (!IMAP_PASS) throw new Error('IMAP_PASS not configured — cannot auto-retrieve email code. Set IMAP_PASS for deepiriexternals@gmail.com');
    console.log('[PlakyBridge] Waiting for email code via IMAP...');
    const code = await fetchPlakyCode(90000, 3000);
    console.log(`[PlakyBridge] Code retrieved: ${code.slice(0, 2)}****`);

    const codeSels = ['input[inputmode="numeric"]', 'input[placeholder*="code" i]', 'input[name="code"]', 'input[type="text"][maxlength="6"]', 'input[type="text"]'];
    // Try 6 inputs (one per digit) or single input
    const single = await this.page.locator(codeSels.join(',')).first().isVisible().catch(() => false);
    if (single) {
      // If 6 boxes, fill sequentially
      const boxes = this.page.locator('input[inputmode="numeric"], input[maxlength="1"]');
      const count = await boxes.count().catch(() => 0);
      if (count >= 6) {
        for (let i = 0; i < 6; i++) {
          try { await boxes.nth(i).fill(code[i]); } catch {}
        }
      } else {
        for (const s of codeSels) {
          try { await this.page.fill(s, code, { timeout: 3000 }); break; } catch {}
        }
      }
    } else {
      throw new Error('Could not find code input');
    }

    const verifySels = ['button:has-text("Verify")', 'button:has-text("Continue")', 'button:has-text("Sign in")', 'button[type="submit"]'];
    for (const s of verifySels) {
      try { await this.page.click(s, { timeout: 3000 }); break; } catch {}
    }
    await this.page.waitForLoadState('networkidle', { timeout: 20000 }).catch(() => {});
    await this.page.waitForTimeout(3000);
    if (this.page.url().includes('/login')) {
      const body = await this.page.content();
      throw new Error(`Code login failed, still on login: ${body.slice(0, 800)}`);
    }
    await this.saveSession();
    console.log('[PlakyBridge] Login success via email code');
  }

  private startSessionRefresh() {
    if (this.refreshTimer) clearInterval(this.refreshTimer);
    this.refreshTimer = setInterval(async () => {
      try {
        if (!this.page) return;
await this.page.goto('https://deepiri-crew.plaky.com/dashboard', { waitUntil: 'networkidle', timeout: 15000 });
        await this.saveSession();
        console.log('[PlakyBridge] Session refreshed');
      } catch (e) {
        console.warn('[PlakyBridge] Refresh failed, re-login', e);
        try { await this.login(); } catch {}
      }
    }, 30 * 60 * 1000);
  }

  // Real API membership check — fast, authoritative, no browser needed
  async checkViaApi(email: string): Promise<{ exists: boolean; user?: any }> {
    if (!PLAKY_API_KEY) return { exists: false };
    try {
      const r = await axios.get(`${PLAKY_API_BASE}/users`, {
        headers: { 'X-API-Key': PLAKY_API_KEY },
        params: { emails: [email] },
        timeout: 8000,
      });
      const users = r.data?.data || [];
      const found = users.find((u: any) => u.email?.toLowerCase() === email.toLowerCase());
      return { exists: !!found, user: found };
    } catch (e: any) {
      console.warn(`[PlakyBridge] API check failed for ${email}: ${e.message}`);
      return { exists: false };
    }
  }

  async inviteUser(email: string, role: string = 'MEMBER'): Promise<InviteResult> {
    // 1) Real API check — if already member, short-circuit
    const check = await this.checkViaApi(email);
    if (check.exists) {
      return { success: false, email, role, error: `Already a workspace member (${check.user?.type}/${check.user?.status})`, via: 'check-only', status: 'exists' };
    }

    // 2) If no browser creds, we cannot automate — return instructive error (real API has no invite endpoint)
    if (!this.page || !this.browser) {
      return {
        success: false,
        email,
        role,
        error: 'Plaky public API has no invite endpoint (verified docs.plaky.com — only GET /users). Browser automation requires PLAKY_EMAIL (deepiriexternals@gmail.com) + IMAP_PASS for code retrieval. Set them in platform env to enable headless invites.',
        via: 'api',
      };
    }

    // 3) Cake Account API invite (captcha-free, SSO cookie) — see inviteUserViaCake.
    const viaCake = await this.inviteUserViaCake(email);
    if (viaCake.success) return viaCake;
    console.warn(`[PlakyBridge] Cake invite failed (${viaCake.error}); falling back to SPA modal then web API check`);

    // 4) Browser automation — navigate to the correct SPA domain and use the
    // proven "Invite new members" modal flow (headless). Fallback only.
    try {
      console.log(`[PlakyBridge] Headless invite (SPA fallback) ${email} role=${role}`);
      await this.gotoDashboard();

      // Open the Invite new members modal — the SPA renders this button on the
      // dashboard. Using page.evaluate to find + click avoids flaky locator
      // chains that break across SPA route changes.
      await this.page!.evaluate(() => {
        const btn = Array.from(document.querySelectorAll('button')).find(
          (b) => b.textContent?.includes('Invite new members') || b.textContent?.includes('Invite')
        );
        if (btn) btn.click();
      });
      await this.page!.waitForTimeout(2500);

      // Fill email — the "Invite new members" modal has an email input.
      const emailInput = this.page!.locator('input[placeholder*="email" i], input[type="email"]').last();
      const emailVisible = await emailInput.isVisible().catch(() => false);
      if (!emailVisible) {
        // Fallback: navigate directly to the users admin page
        await this.page!.goto('https://deepiri-crew.plaky.com/admin/users', { waitUntil: 'networkidle', timeout: 12000 });
        await this.page!.waitForTimeout(1500);
        await this.page!.evaluate(() => {
          const btn = Array.from(document.querySelectorAll('button')).find(
            (b) => b.textContent?.includes('Invite new members') || b.textContent?.includes('Invite')
          );
          if (btn) btn.click();
        });
        await this.page!.waitForTimeout(2500);
      }
      const finalInput = this.page!.locator('input[placeholder*="email" i], input[type="email"]').last();
      await finalInput.fill(email, { timeout: 8000 });
      await finalInput.press('Enter');
      await this.page!.waitForTimeout(1500);

      // Click the "Invite" button in the modal
      const inviteBtn = this.page!.locator('button:has-text("Invite")').last();
      await inviteBtn.click({ timeout: 4000 });
      console.log(`[PlakyBridge] Invite modal sent for ${email}`);

      // Wait for success and verify via API
      await this.page!.waitForTimeout(3000);
      for (let i = 0; i < 3; i++) {
        await new Promise(r => setTimeout(r, 2000));
        const recheck = await this.checkViaApi(email);
        if (recheck.exists) {
          return { success: true, email, role, status: recheck.user?.status || 'PENDING', via: 'browser' };
        }
      }
      return { success: true, email, role, status: 'pending', via: 'browser' };
    } catch (e: any) {
      console.error(`[PlakyBridge] invite failed for ${email}:`, e.message);
      try { await this.page!.screenshot({ path: '/tmp/plaky_invite_fail.png' }); } catch {}
      await this.recoverSession().catch(() => {});
      return { success: false, email, role, error: e.message, via: 'browser' };
    }
  }

  // Resolve the browser session's Bearer (plaky_session) JWT so we can call the
  // same web API the SPA uses — verified working for deactivation. Reads the
  // token out of the page's localStorage ('user.accessToken') like the proved
  // capture scripts do.
  private async getSessionAccessToken(): Promise<string | null> {
    if (!this.page) return null;
    try {
      const token = await this.page.evaluate(() => {
        try {
          const user = JSON.parse(localStorage.getItem('user') || '{}') as any;
          if (typeof user?.accessToken === 'string' && user.accessToken) return user.accessToken;
          if (typeof user?.token === 'string' && user.token) return user.token;
        } catch {}
        return null;
      });
      return token;
    } catch {
      return null;
    }
  }

  private async gotoDashboard() {
    if (!this.page) return;
    await this.page.goto('https://deepiri-crew.plaky.com/', { waitUntil: 'networkidle', timeout: 15000 });
    await this.page.waitForTimeout(1500);
  }

  async kickUser(email: string): Promise<InviteResult> {
    const check = await this.checkViaApi(email);
    if (!check.exists) {
      return { success: false, email, error: 'User not found in workspace', via: 'check-only' };
    }
    // Prefer the verified web API deactivate path (PATCH /users/{id}/deactivate
    // with the browser session Bearer) — far more robust than DOM menu scraping.
    const userId = check.user?.id;
    if (userId && this.page && this.browser) {
      try {
        await this.gotoDashboard();
        const token = await this.getSessionAccessToken();
        if (token) {
          // Deactivate with 429 backoff (verified live: first deactivate hit
          // TOO_MANY_REQUESTS, succeeded on the retry).
          let deact: any;
          for (let tries = 0; tries < 4; tries++) {
            try {
              deact = await axios.patch(
                `https://deepiri-crew.api.plaky.com/users/${userId}/deactivate`,
                {},
                {
                  headers: {
                    Authorization: `Bearer ${token}`,
                    'x-client-platform': 'web',
                    'x-client-version': '2.5.3',
                    'x-client-session-id': this.page.evaluate(() => sessionStorage.getItem('sessionId') || '') as any,
                  },
                  timeout: 15000,
                },
              );
              break;
            } catch (err: any) {
              if (err?.response?.status === 429 && tries < 3) {
                const delay = 2500 * (tries + 1);
                console.warn(`[PlakyBridge] Deactivate rate-limited (429), backing off ${delay}ms before retry`);
                await new Promise((r) => setTimeout(r, delay));
                continue;
              }
              throw err;
            }
          }
          if (deact && deact.status >= 200 && deact.status < 300) {
            // Verify via API
            for (let i = 0; i < 3; i++) {
              await new Promise(r => setTimeout(r, 1500));
              const recheck = await this.checkViaApi(email);
              if (!recheck.exists || recheck.user?.status === 'INACTIVE' || recheck.user?.status === 'DEACTIVATED') {
                return { success: true, email, status: `deactivated (${recheck.user?.status || 'INACTIVE'})`, via: 'browser' };
              }
              if (!recheck.exists) {
                return { success: true, email, status: 'removed', via: 'browser' };
              }
            }
            return { success: true, email, status: 'deactivated', via: 'browser' };
          }
          console.warn(`[PlakyBridge] Web API deactivate for ${email} returned ${deact.status}`);
        }
      } catch (e: any) {
        console.warn(`[PlakyBridge] Web API deactivate failed for ${email}, falling back to DOM: ${e.message}`);
      }
    }
    if (!this.page || !this.browser) {
      return {
        success: false,
        email,
        error: 'Plaky public API has no delete/kick endpoint and no browser session available. Browser automation requires PLAKY_EMAIL + IMAP_PASS for code login.',
        via: 'api',
      };
    }
    try {
      console.log(`[PlakyBridge] Headless kick (DOM fallback) ${email}`);
      await this.page!.goto('https://deepiri-crew.plaky.com/admin/users', { waitUntil: 'networkidle', timeout: 15000 });
      await this.page!.waitForTimeout(1500);

      // Search for user row — try to find by email text
      const row = this.page!.locator(`tr:has-text("${email}"), div:has-text("${email}")`).first();
      // Click three-dots menu then Remove/Deactivate
      const menuSelectors = ['button:has-text("...")', '[data-testid="user-menu"]', 'button[aria-label="More"]'];
      // Fallback: use locator for row menu
      try {
        await row.locator('button').last().click({ timeout: 4000 });
      } catch {
        for (const sel of menuSelectors) {
          try { await this.page!.click(sel, { timeout: 3000 }); break; } catch {}
        }
      }
      await this.page!.waitForTimeout(800);
      const removeSels = ['text=Remove from workspace', 'text=Deactivate', 'text=Remove', 'button:has-text("Remove")'];
      let clicked = false;
      for (const sel of removeSels) {
        try { await this.page!.click(sel, { timeout: 3000 }); clicked = true; break; } catch {}
      }
      if (!clicked) throw new Error('Could not find remove button');
      // Confirm modal
      await this.page!.waitForTimeout(800);
      for (const sel of ['button:has-text("Confirm")', 'button:has-text("Remove")', 'button:has-text("Yes")']) {
        try { await this.page!.click(sel, { timeout: 3000 }); break; } catch {}
      }
      await this.page!.waitForTimeout(2000);
      // Verify via API
      for (let i = 0; i < 3; i++) {
        await new Promise(r => setTimeout(r, 1500));
        const recheck = await this.checkViaApi(email);
        if (!recheck.exists || recheck.user?.status === 'INACTIVE') {
          return { success: true, email, status: 'removed', via: 'browser' };
        }
      }
      return { success: true, email, status: 'pending-removal', via: 'browser' };
    } catch (e: any) {
      console.error(`[PlakyBridge] kick failed for ${email}:`, e.message);
      await this.recoverSession().catch(() => {});
      return { success: false, email, error: e.message, via: 'browser' };
    }
  }

  // ---------- Cake Account API (captcha-free invites) ----------

  // Read the account.cake.com Sso-Token cookie out of the live browser context.
  private async cakeCookieValue(): Promise<string | null> {
    if (!this.context) return null;
    try {
      const cookies = await this.context.cookies('https://account.cake.com');
      const sso = cookies.find((c) => c.name === 'Sso-Token');
      return sso?.value || null;
    } catch {
      return null;
    }
  }

  // The Plaky SSO iframe refreshes the cake Sso-Token cookie when we land on the
  // plaky app. Navigate there (and, last resort, straight to the cake members
  // admin) so the cookie is fresh for API calls.
  private async refreshCakeSession(): Promise<boolean> {
    if (!this.page) return false;
    try {
      await this.page.goto('https://deepiri-crew.plaky.com/', { waitUntil: 'networkidle', timeout: 20000 });
      await this.page.waitForTimeout(2000);
      if (await this.cakeCookieValue()) return true;
      await this.page.goto(`https://account.cake.com/organization/${CAKE_ORGANIZATION_ID}/members/organization-members`, {
        waitUntil: 'domcontentloaded',
        timeout: 25000,
      });
      await this.page.waitForTimeout(2500);
      return !!(await this.cakeCookieValue());
    } catch (e: any) {
      console.warn(`[PlakyBridge] refreshCakeSession failed: ${e.message}`);
      return false;
    }
  }

  private cakeHeaders(token: string) {
    return {
      'Content-Type': 'application/json',
      'Cookie': `Sso-Token=${token}`,
      'Origin': 'https://account.cake.com',
      'Referer': `https://account.cake.com/organization/${CAKE_ORGANIZATION_ID}/members/organization-members`,
    };
  }

  // Low-level cake invite. Exact shape captured from the members admin SPA:
  //   POST {api}/organizations/{org}/workspaces/invitations/new-users
  //   {"workspaceIds":[...],"invitees":[{"email":...,"name":null,"failedValidations":[]}]}
  private async cakeInviteEmails(emails: string[]): Promise<{ ok: boolean; failed: Record<string, any> }> {
    const token = await this.cakeCookieValue();
    if (!token) throw new Error('No cake Sso-Token cookie in session');
    const r = await axios.post(
      `${CAKE_API_BASE}/organizations/${CAKE_ORGANIZATION_ID}/workspaces/invitations/new-users`,
      {
        workspaceIds: CAKE_WORKSPACE_IDS,
        invitees: emails.map((email) => ({ email, name: null, failedValidations: [] })),
      },
      { headers: this.cakeHeaders(token), timeout: 20000 },
    );
    const failed = (r.data && r.data.failedInvitations) || {};
    return { ok: r.status === 200, failed };
  }

  // Find a (possibly PENDING) cake member by email — authoritative post-invite check.
  private async findCakeUser(email: string): Promise<any | null> {
    const token = await this.cakeCookieValue();
    if (!token) return null;
    try {
      const r = await axios.get(`${CAKE_API_BASE}/organizations/${CAKE_ORGANIZATION_ID}/users/own`, {
        headers: this.cakeHeaders(token),
        params: { page: 0, size: 25, sort: 'name,ASC', search: email, wsRole: '', status: '' },
        timeout: 15000,
      });
      const content: any[] = r.data?.content || [];
      return content.find((u) => (u.email || '').toLowerCase() === email.toLowerCase()) || null;
    } catch {
      return null;
    }
  }

  // Invite via the Cake Account members API — captcha-free, SSO-cookie only.
  // This bypasses Plaky's hard captcha gate on POST /users/invitation.
  async inviteUserViaCake(email: string): Promise<InviteResult> {
    if (!this.context) {
      return { success: false, email, error: 'No browser session — cannot reach Cake API', via: 'cake' };
    }
    if (!(await this.cakeCookieValue())) {
      await this.refreshCakeSession();
    }
    for (let attempt = 0; attempt < 4; attempt++) {
      try {
        const res = await this.cakeInviteEmails([email]);
        if (res.ok && Object.keys(res.failed).length === 0) {
          await this.page?.waitForTimeout(1200);
          const member = await this.findCakeUser(email);
          return { success: true, email, status: member?.status || 'PENDING', via: 'cake' };
        }
        const fail = res.failed[email];
        const failMsg =
          (fail && (fail.failedValidations || []).join('; ')) ||
          (fail && fail.message) ||
          (fail && JSON.stringify(fail)) ||
          'unknown (maybe already pending/invited)';
        return { success: false, email, error: `Cake invite rejected: ${failMsg}`, via: 'cake' };
      } catch (e: any) {
        const status = e?.response?.status;
        if (status === 401 && attempt === 0) {
          console.warn('[PlakyBridge] Cake Sso-Token expired, refreshing session');
          await this.refreshCakeSession();
          continue;
        }
        // Cake rate-limits invite bursts (429) — back off and retry.
        if (status === 429 && attempt < 3) {
          const delay = 3000 * (attempt + 1);
          console.warn(`[PlakyBridge] Cake invite rate-limited (429), backing off ${delay}ms before retry`);
          await new Promise((r) => setTimeout(r, delay));
          continue;
        }
        // Distinguish "already invited / already a member" (409-ish, idempotent
        // no-op) from genuine failures so the server can map it to 409.
        const rawMsg =
          (e?.response?.data && JSON.stringify(e?.response?.data).slice(0, 300)) ||
          (e?.response && `HTTP ${e.response.status}`) ||
          e.message;
        const normalized = (rawMsg || '').replace(/"+/g, '');
        const already = /already|invited|pending|exist|member/i.test(normalized);
        return {
          success: false,
          email,
          error: `${already ? 'Already ' : 'Cake invite failed: '}${rawMsg}`.slice(0, 400),
          via: 'cake',
        };
      }
    }
    return { success: false, email, error: 'Cake invite failed after session refresh', via: 'cake' };
  }

  async recoverSession() {
    try { await this.login(); return true; } catch { return false; }
  }

  async close() {
    if (this.refreshTimer) clearInterval(this.refreshTimer);
    if (this.browser) await this.browser.close();
    this.isReady = false;
  }
}
