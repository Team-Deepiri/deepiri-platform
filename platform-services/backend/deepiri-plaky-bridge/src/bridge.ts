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

export type InviteResult = {
  success: boolean;
  email: string;
  role?: string;
  status?: string;
  error?: string;
  via: 'api' | 'browser' | 'check-only';
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
      await this.page.goto('https://app.plaky.com/dashboard', { waitUntil: 'networkidle', timeout: 15000 });
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
    await this.page.goto('https://app.plaky.com/login', { waitUntil: 'networkidle', timeout: 20000 });

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
        await this.page.goto('https://app.plaky.com/dashboard', { waitUntil: 'networkidle', timeout: 15000 });
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

    // 3) Browser automation — 100% headless
    try {
      console.log(`[PlakyBridge] Headless invite ${email} role=${role}`);
      // Navigate to workspace members area — Plaky uses Administration → Users
      await this.page!.goto('https://app.plaky.com/dashboard', { waitUntil: 'networkidle', timeout: 15000 });
      await this.page!.waitForTimeout(1500);

      // Try to open Users/Invite modal via multiple strategies
      const inviteSelectors = [
        'button:has-text("Invite")',
        'button:has-text("Invite members")',
        'button:has-text("Invite new members")',
        '[data-testid="invite-button"]',
        'text=Invite new members',
        'text=Users',
      ];
      let opened = false;
      for (const sel of inviteSelectors) {
        try {
          // For "Users" we navigate via SPA routing if needed
          if (sel === 'text=Users') {
            await this.page!.goto('https://app.plaky.com/administration/users', { waitUntil: 'networkidle', timeout: 10000 }).catch(() => {});
            await this.page!.waitForTimeout(1000);
          }
          await this.page!.click(sel, { timeout: 3000 });
          opened = true;
          await this.page!.waitForTimeout(1000);
          // Check if email input appeared
          const emailInput = await this.page!.locator('input[type="email"], input[placeholder*="email" i]').first().isVisible().catch(() => false);
          if (emailInput) break;
        } catch {}
      }
      if (!opened) {
        // Fallback: try direct navigation to users admin
        await this.page!.goto('https://app.plaky.com/administration/users', { waitUntil: 'networkidle', timeout: 10000 });
        await this.page!.waitForTimeout(1500);
        for (const sel of ['button:has-text("Invite")', '[data-testid="invite-button"]']) {
          try { await this.page!.click(sel, { timeout: 3000 }); opened = true; break; } catch {}
        }
      }
      if (!opened) {
        // debug dump
        try {
          const html = await this.page!.content();
          await this.page!.screenshot({ path: '/tmp/plaky_invite_fail.png' }).catch(() => {});
          console.log('[PlakyBridge] Invite modal not opened, url', this.page!.url());
          console.log('[PlakyBridge] Page snippet', html.slice(0, 8000));
          const buttons = await this.page!.locator('button').all().then(async els => {
            const texts: string[] = [];
            for (const e of els.slice(0, 60)) {
              try { const t = await e.innerText(); if (t.trim()) texts.push(t.slice(0, 80)); } catch {}
            }
            return texts;
          });
          console.log('[PlakyBridge] Buttons', buttons);
        } catch {}
        throw new Error('Could not open invite modal (selectors changed?)');
      }

      await this.page!.waitForSelector('input[type="email"], input[placeholder*="email" i]', { timeout: 7000 });
      const emailSelectors = ['input[type="email"]', 'input[placeholder*="email" i]', '[data-testid="email-input"]'];
      let filled = false;
      for (const sel of emailSelectors) {
        try { await this.page!.fill(sel, email, { timeout: 3000 }); filled = true; break; } catch {}
      }
      if (!filled) throw new Error('Could not fill email input');

      // Role select if not default
      if (role && role.toUpperCase() !== 'MEMBER') {
        for (const sel of ['select#role', 'select[name="role"]', '[data-testid="role-select"]']) {
          try { await this.page!.selectOption(sel, role.toLowerCase()); break; } catch {}
        }
      }

      const sendSelectors = ['button:has-text("Send Invite")', 'button:has-text("Invite")', 'button:has-text("Add")', '[data-testid="send-invite"]'];
      let sent = false;
      for (const sel of sendSelectors) {
        try { await this.page!.click(sel, { timeout: 4000 }); sent = true; break; } catch {}
      }
      if (!sent) throw new Error('Could not click send invite');

      // Wait for success toast or check API again
      await this.page!.waitForTimeout(2000);
      // Verify via API poll (authoritative)
      for (let i = 0; i < 3; i++) {
        await new Promise(r => setTimeout(r, 1500));
        const recheck = await this.checkViaApi(email);
        if (recheck.exists) {
          return { success: true, email, role, status: recheck.user?.status || 'PENDING', via: 'browser' };
        }
      }
      // If no verification, assume pending (email invite sent)
      return { success: true, email, role, status: 'pending', via: 'browser' };
    } catch (e: any) {
      console.error('[PlakyBridge] invite failed for %s: %s', email, e.message);
      await this.recoverSession().catch(() => {});
      return { success: false, email, role, error: e.message, via: 'browser' };
    }
  }

  async kickUser(email: string): Promise<InviteResult> {
    const check = await this.checkViaApi(email);
    if (!check.exists) {
      return { success: false, email, error: 'User not found in workspace', via: 'check-only' };
    }
    if (!this.page || !this.browser) {
      return {
        success: false,
        email,
        error: 'Plaky public API has no delete/kick endpoint. Browser automation requires PLAKY_EMAIL + IMAP_PASS for code login.',
        via: 'api',
      };
    }
    try {
      console.log(`[PlakyBridge] Headless kick ${email}`);
      await this.page!.goto('https://app.plaky.com/administration/users', { waitUntil: 'networkidle', timeout: 15000 });
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
      console.error('[PlakyBridge] kick failed for %s: %s', email, e.message);
      await this.recoverSession().catch(() => {});
      return { success: false, email, error: e.message, via: 'browser' };
    }
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
