import prisma from './db';
import { createJob, getJob, JobRecord } from './services/jobsClient';

type StepStatus = 'queued' | 'running' | 'waiting' | 'completed' | 'failed' | 'cancelled';

interface TrussStep {
  id: string;
  kind: 'jobStep' | 'conditionStep' | 'waitEventStep';
  name?: string;
  job?: {
    type: string;
    payloadFrom?: string;
    labels?: Record<string, string>;
  };
  condition?: {
    path: string;
    equals: unknown;
  };
  event?: {
    type: string;
    correlationPath?: string;
  };
}

interface RunContext {
  input: Record<string, unknown>;
  steps: Record<string, unknown>;
}

const TERMINAL_STATUSES: StepStatus[] = ['completed', 'failed', 'cancelled'];

interface StepRunRecord {
  id: string;
  stepId: string;
  status: string;
  output: unknown;
  externalRef: string | null;
}

function asObject(value: unknown): Record<string, unknown> {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function getPath(source: Record<string, unknown>, path: string): unknown {
  return path.split('.').reduce<unknown>((current, segment) => {
    if (current && typeof current === 'object' && segment in current) {
      return (current as Record<string, unknown>)[segment];
    }
    return undefined;
  }, source);
}

function buildRunContext(
  input: unknown,
  stepRuns: Array<{ stepId: string; status: string; output: unknown }>
): RunContext {
  const steps: Record<string, unknown> = {};
  for (const stepRun of stepRuns) {
    steps[stepRun.stepId] = {
      status: stepRun.status,
      output: stepRun.output ?? {},
    };
  }

  return {
    input: asObject(input),
    steps,
  };
}

function setStepContext(context: RunContext, stepId: string, status: StepStatus, output: unknown): void {
  context.steps[stepId] = {
    status,
    output: output ?? {},
  };
}

function resolvePayload(payloadFrom: string | undefined, context: RunContext): Record<string, unknown> {
  if (!payloadFrom) {
    return context.input;
  }

  const value = getPath(context as unknown as Record<string, unknown>, payloadFrom);
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }

  return {};
}

function mapJobStatus(job: JobRecord): StepStatus {
  if (job.status === 'completed') return 'completed';
  if (job.status === 'failed') return 'failed';
  if (job.status === 'cancelled') return 'cancelled';
  return 'running';
}

async function failRunAtStep(runId: string, stepRunId: string, stepId: string, error: string): Promise<void> {
  const now = new Date();
  await prisma.trussStepRun.update({
    where: { id: stepRunId },
    data: {
      status: 'failed',
      error,
      completedAt: now,
    },
  });
  await prisma.trussRun.update({
    where: { id: runId },
    data: {
      status: 'failed',
      error,
      currentStep: stepId,
      completedAt: now,
    },
  });
}

async function executeJobStep(runId: string, step: TrussStep, context: RunContext): Promise<{
  status: StepStatus;
  job: JobRecord;
}> {
  if (!step.job?.type) {
    throw new Error(`jobStep ${step.id} is missing job.type`);
  }

  const job = await createJob({
    type: step.job.type,
    payload: resolvePayload(step.job.payloadFrom, context),
    labels: {
      ...(step.job.labels ?? {}),
      trussRunId: runId,
      trussStepId: step.id,
    },
    idempotencyKey: `truss:${runId}:${step.id}`,
  });

  return {
    status: mapJobStatus(job),
    job,
  };
}

function executeConditionStep(step: TrussStep, context: RunContext): {
  status: StepStatus;
  output: Record<string, unknown>;
  error?: string;
} {
  if (!step.condition) {
    return {
      status: 'failed',
      output: {},
      error: `conditionStep ${step.id} is missing condition`,
    };
  }

  const actual = getPath(context as unknown as Record<string, unknown>, step.condition.path);
  const passed = actual === step.condition.equals;
  const output = {
    path: step.condition.path,
    expected: step.condition.equals ?? null,
    actual: actual ?? null,
    passed,
  };

  return {
    status: passed ? 'completed' : 'failed',
    output,
    error: passed ? undefined : `Condition failed for ${step.condition.path}`,
  };
}

function executeWaitEventStep(step: TrussStep): {
  status: StepStatus;
  output: Record<string, unknown>;
} {
  return {
    status: 'waiting',
    output: {
      waitingFor: step.event ?? {},
      reason: 'Event correlation is not implemented in the Phase 1 MVP',
    },
  };
}

export async function startRun(runId: string): Promise<void> {
  await prisma.trussRun.update({
    where: { id: runId },
    data: {
      status: 'running',
      startedAt: new Date(),
    },
  });

  await advanceRun(runId);
}

export async function advanceRun(runId: string): Promise<void> {
  const run = await prisma.trussRun.findUnique({
    where: { id: runId },
    include: {
      definition: true,
      stepRuns: { orderBy: { createdAt: 'asc' } },
    },
  });

  if (!run || TERMINAL_STATUSES.includes(run.status as StepStatus)) {
    return;
  }

  const steps = run.definition.steps as unknown as TrussStep[];
  const stepRuns = run.stepRuns as unknown as StepRunRecord[];
  const context = buildRunContext(run.input, stepRuns);

  for (const step of steps) {
    let stepRun = stepRuns.find((candidate) => candidate.stepId === step.id);

    if (stepRun && TERMINAL_STATUSES.includes(stepRun.status as StepStatus)) {
      continue;
    }

    if (stepRun?.status === 'waiting') {
      await prisma.trussRun.update({
        where: { id: run.id },
        data: { status: 'waiting', currentStep: step.id },
      });
      return;
    }

    if (stepRun?.status === 'running' && step.kind === 'jobStep' && stepRun.externalRef) {
      let job: JobRecord;
      try {
        job = await getJob(stepRun.externalRef);
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : 'Failed to poll Jobs service';
        await failRunAtStep(run.id, stepRun.id, step.id, message);
        return;
      }

      const status = mapJobStatus(job);
      const completedAt = TERMINAL_STATUSES.includes(status) ? new Date() : null;

      stepRun = await prisma.trussStepRun.update({
        where: { id: stepRun.id },
        data: {
          status,
          output: job as any,
          error: job.error ?? null,
          completedAt,
        },
      });
      setStepContext(context, step.id, status, job);

      if (status === 'running') {
        await prisma.trussRun.update({
          where: { id: run.id },
          data: { status: 'running', currentStep: step.id },
        });
        return;
      }

      if (status === 'failed' || status === 'cancelled') {
        await prisma.trussRun.update({
          where: { id: run.id },
          data: {
            status,
            error: job.error ?? `Job ${status}`,
            currentStep: step.id,
            completedAt: new Date(),
          },
        });
        return;
      }

      continue;
    }

    const activeStepRun = await prisma.trussStepRun.create({
      data: {
        runId: run.id,
        stepId: step.id,
        kind: step.kind,
        status: 'running',
        input: step as any,
        startedAt: new Date(),
      },
    });

    await prisma.trussRun.update({
      where: { id: run.id },
      data: { currentStep: step.id, status: 'running' },
    });

    if (step.kind === 'jobStep') {
      let result: { status: StepStatus; job: JobRecord };
      try {
        result = await executeJobStep(run.id, step, context);
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : 'Failed to submit jobStep';
        await failRunAtStep(run.id, activeStepRun.id, step.id, message);
        return;
      }

      const completedAt = result.status === 'completed' ? new Date() : null;

      await prisma.trussStepRun.update({
        where: { id: activeStepRun.id },
        data: {
          status: result.status,
          externalRef: result.job.id,
          output: result.job as any,
          error: result.job.error ?? null,
          completedAt,
        },
      });
      setStepContext(context, step.id, result.status, result.job);

      if (result.status !== 'completed') {
        await prisma.trussRun.update({
          where: { id: run.id },
          data: { status: result.status, currentStep: step.id },
        });
        return;
      }

      continue;
    }

    if (step.kind === 'conditionStep') {
      const result = executeConditionStep(step, context);

      await prisma.trussStepRun.update({
        where: { id: activeStepRun.id },
        data: {
          status: result.status,
          output: result.output as any,
          error: result.error ?? null,
          completedAt: new Date(),
        },
      });
      setStepContext(context, step.id, result.status, result.output);

      if (result.status === 'failed') {
        await prisma.trussRun.update({
          where: { id: run.id },
          data: {
            status: 'failed',
            error: result.error,
            currentStep: step.id,
            completedAt: new Date(),
          },
        });
        return;
      }

      continue;
    }

    if (step.kind === 'waitEventStep') {
      const result = executeWaitEventStep(step);

      await prisma.trussStepRun.update({
        where: { id: activeStepRun.id },
        data: {
          status: result.status,
          output: result.output as any,
        },
      });
      setStepContext(context, step.id, result.status, result.output);

      await prisma.trussRun.update({
        where: { id: run.id },
        data: { status: 'waiting', currentStep: step.id },
      });
      return;
    }

    await prisma.trussStepRun.update({
      where: { id: activeStepRun.id },
      data: {
        status: 'failed',
        error: `Unsupported step kind: ${step.kind}`,
        completedAt: new Date(),
      },
    });

    await prisma.trussRun.update({
      where: { id: run.id },
      data: {
        status: 'failed',
        error: `Unsupported step kind: ${step.kind}`,
        currentStep: step.id,
        completedAt: new Date(),
      },
    });
    return;
  }

  await prisma.trussRun.update({
    where: { id: run.id },
    data: {
      status: 'completed',
      currentStep: null,
      completedAt: new Date(),
    },
  });
}

export async function reconcileRun(runId: string): Promise<void> {
  await advanceRun(runId);
}
