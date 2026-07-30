/**
 * Jobs / Truss (workflow-orchestrator) → deepiri-speech HTTP client.
 * Batch STT/TTS for workflow steps — not the LiveKit media path.
 */
import { secureLog } from '@team-deepiri/shared-utils';

const SPEECH_URL = (process.env.SPEECH_URL || 'http://speech:5020').replace(/\/$/, '');

export type SttResult = {
  text: string;
  is_final?: boolean;
  language?: string;
  provider?: string;
  model?: string;
  confidence?: number;
};

export async function speechHealth(): Promise<Record<string, unknown>> {
  const res = await fetch(`${SPEECH_URL}/health`);
  if (!res.ok) {
    throw new Error(`speech health ${res.status}`);
  }
  return res.json() as Promise<Record<string, unknown>>;
}

export async function transcribeAudio(
  audio: Buffer | Uint8Array,
  opts: {
    filename?: string;
    mimeType?: string;
    language?: string;
    sessionId?: string;
  } = {}
): Promise<SttResult> {
  const form = new FormData();
  form.append(
    'file',
    new Blob([Uint8Array.from(audio)], { type: opts.mimeType || 'audio/wav' }),
    opts.filename || 'audio.wav'
  );

  if (opts.language) form.append('language', opts.language);
  if (opts.sessionId) form.append('session_id', opts.sessionId);

  const res = await fetch(`${SPEECH_URL}/v1/stt`, { method: 'POST', body: form });
  if (!res.ok) {
    const body = await res.text();
    secureLog('error', 'speech STT failed', { status: res.status, body });
    throw new Error(`speech STT ${res.status}`);
  }
  return res.json() as Promise<SttResult>;
}

export async function synthesizeSpeech(
  text: string,
  opts: { voice?: string; sessionId?: string } = {}
): Promise<{ audio: ArrayBuffer; contentType: string }> {
  const res = await fetch(`${SPEECH_URL}/v1/tts`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      text,
      voice: opts.voice,
      session_id: opts.sessionId,
    }),
  });
  if (!res.ok) {
    const body = await res.text();
    secureLog('error', 'speech TTS failed', { status: res.status, body });
    throw new Error(`speech TTS ${res.status}`);
  }
  return {
    audio: await res.arrayBuffer(),
    contentType: res.headers.get('content-type') || 'application/octet-stream',
  };
}

export { SPEECH_URL };
