export type JobStatus = 'queued' | 'running' | 'completed' | 'failed' | 'cancelled';

export interface CreateJobRequest {
  type: string;
  payload?: Record<string, unknown>;
  labels?: Record<string, string>;
  idempotencyKey?: string;
}

export interface JobRecord {
  id: string;
  type: string;
  status: JobStatus;
  payload: Record<string, unknown>;
  labels: Record<string, string>;
  idempotencyKey?: string;
  createdAt: string;
  updatedAt: string;
  result?: Record<string, unknown>;
  error?: string;
}

function resolveJobsUrl(): string {
  const jobsUrl = process.env.JOBS_URL?.trim();
  if (!jobsUrl) {
    throw new Error('JOBS_URL is not configured');
  }
  return jobsUrl.replace(/\/$/, '');
}

async function parseJsonResponse(res: Response): Promise<Record<string, unknown>> {
  return (await res.json().catch(() => ({}))) as Record<string, unknown>;
}

export async function createJob(request: CreateJobRequest): Promise<JobRecord> {
  const res = await fetch(`${resolveJobsUrl()}/api/jobs`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(request),
  });

  const body = await parseJsonResponse(res);
  if (!res.ok) {
    throw new Error(`Jobs service returned ${res.status}: ${body.error ?? 'create job failed'}`);
  }

  return body as unknown as JobRecord;
}

export async function getJob(jobId: string): Promise<JobRecord> {
  const res = await fetch(`${resolveJobsUrl()}/api/jobs/${jobId}`);
  const body = await parseJsonResponse(res);

  if (!res.ok) {
    throw new Error(`Jobs service returned ${res.status}: ${body.error ?? 'get job failed'}`);
  }

  return body as unknown as JobRecord;
}