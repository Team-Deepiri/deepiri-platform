import Imap from 'imap';
import { simpleParser } from 'mailparser';

const IMAP_HOST = process.env.IMAP_HOST || 'imap.gmail.com';
const IMAP_PORT = parseInt(process.env.IMAP_PORT || '993', 10);
const IMAP_USER = process.env.IMAP_USER || process.env.PLAKY_BOT_EMAIL || '';
const IMAP_PASS = process.env.IMAP_PASS || '';

function imapConfig() {
  return {
    user: IMAP_USER,
    password: IMAP_PASS,
    host: IMAP_HOST,
    port: IMAP_PORT,
    tls: true,
    tlsOptions: { rejectUnauthorized: false },
    connTimeout: 10000,
    authTimeout: 10000,
  };
}

export async function fetchPlakyCode(timeoutMs = 90000, pollIntervalMs = 3000): Promise<string> {
  if (!IMAP_USER || !IMAP_PASS) throw new Error('IMAP_USER/IMAP_PASS not configured for code retrieval');
  const start = Date.now();
  let lastSeenUid: number | null = null;

  while (Date.now() - start < timeoutMs) {
    const code = await pollOnce(lastSeenUid);
    if (code.code) return code.code;
    if (code.maxUid) lastSeenUid = code.maxUid;
    await new Promise(r => setTimeout(r, pollIntervalMs));
  }
  throw new Error(`Timed out waiting for Plaky code in ${IMAP_USER} inbox after ${timeoutMs / 1000}s`);
}

async function pollOnce(afterUid: number | null): Promise<{ code: string | null; maxUid: number | null }> {
  return new Promise((resolve, reject) => {
    const imap = new (Imap as any)(imapConfig());
    let maxUid: number | null = afterUid;
    let foundCode: string | null = null;

    imap.once('ready', () => {
      imap.openBox('INBOX', false, (err: any, box: any) => {
        if (err) { imap.end(); return reject(err); }
        // Search unseen or recent from Plaky/CAKE
        const since = new Date(Date.now() - 10 * 60 * 1000); // last 10 min
        const criteria: any[] = [['SINCE', since.toISOString().split('T')[0]]];
        // IMAP search is limited; fetch last 20 and filter in JS
        imap.search(criteria, (err: any, results: number[]) => {
          if (err) { imap.end(); return reject(err); }
          if (!results || results.length === 0) { imap.end(); return resolve({ code: null, maxUid }); }
          const toFetch = results.slice(-20); // last 20
          const f = imap.fetch(toFetch, { bodies: '', markSeen: false });
          let pending = toFetch.length;
          let done = false;
          f.on('message', (msg: any) => {
            let uid: number | null = null;
            msg.on('attributes', (attrs: any) => {
              uid = attrs.uid;
              if (uid && (!maxUid || uid > maxUid)) maxUid = uid;
              // skip already seen
              if (afterUid && uid && uid <= afterUid) return;
            });
            msg.on('body', (stream: any) => {
              simpleParser(stream as any, (err: any, parsed: any) => {
                if (err) { pending--; if (pending === 0 && !done) { done = true; imap.end(); resolve({ code: foundCode, maxUid }); } return; }
                const from = (parsed.from?.text || '').toLowerCase();
                const subject = (parsed.subject || '').toLowerCase();
                const text = (parsed.text || '').toString();
                const html = (parsed.html || '').toString();
                const combined = `${subject}\n${text}\n${html}`;
                // Plaky codes are 6 digits, often "Your verification code is 123456" or "Security code"
                const isPlaky = from.includes('plaky') || from.includes('cake') || subject.includes('plaky') || subject.includes('code') || subject.includes('verify') || combined.toLowerCase().includes('plaky');
                if (!isPlaky) { pending--; if (pending === 0 && !done) { done = true; imap.end(); resolve({ code: foundCode, maxUid }); } return; }
                // Only consider messages after start
                const date = parsed.date ? new Date(parsed.date).getTime() : 0;
                if (Date.now() - date > 10 * 60 * 1000) { pending--; if (pending === 0 && !done) { done = true; imap.end(); resolve({ code: foundCode, maxUid }); } return; }
                // Plaky now sends alphanumeric codes like 35NTGH (6 chars A-Z0-9)
                const codeRegex = /\b([A-Z0-9]{6})\b/i;
                const m = combined.match(codeRegex) || combined.match(/\b(\d{4,8})\b/);
                if (m && !foundCode) {
                  // Prefer Login code line: "Your login verification code: 35NTGH"
                  const loginMatch = combined.match(/verification code:\s*([A-Z0-9]{4,8})/i) || combined.match(/Login code[^A-Z0-9]*([A-Z0-9]{4,8})/i);
                  if (loginMatch) foundCode = loginMatch[1].toUpperCase();
                  else {
                    const candidates = [...combined.matchAll(/\b([A-Z0-9]{6})\b/gi)].map(x => x[1]);
                    // Filter out obvious non-codes (like hex from URLs) by requiring isolated code context
                    foundCode = candidates.find(c => /[A-Z]/.test(c) && /[0-9]/.test(c)) || candidates[0] || m[1];
                    if (foundCode) foundCode = foundCode.toUpperCase();
                  }
                }
                pending--;
                if (pending === 0 && !done) { done = true; imap.end(); resolve({ code: foundCode, maxUid }); }
              });
            });
          });
          f.once('error', (err: any) => { if (!done) { done = true; imap.end(); reject(err); } });
          f.once('end', () => {
            if (pending === 0 && !done) { done = true; imap.end(); resolve({ code: foundCode, maxUid }); }
            // If no messages emitted, resolve
            setTimeout(() => { if (!done) { done = true; imap.end(); resolve({ code: foundCode, maxUid }); } }, 2000);
          });
        });
      });
    });
    imap.once('error', (err: any) => reject(err));
    imap.connect();
  });
}
