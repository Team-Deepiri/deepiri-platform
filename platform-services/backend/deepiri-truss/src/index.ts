import express, { Router, Request, Response } from 'express';
import fs from 'fs';
import path from 'path';
import { parse } from 'yaml';
import prisma from './db';
import { startRun, reconcileRun } from './trussEngine';
import { publishTrussRunEvent, publishTrussStepEvent } from './streaming/eventPublisher';

const router: Router = express.Router();

interface TemplateDefinition {
  name: string;
  description?: string;
  metadata?: Record<string, unknown>;
  steps: unknown[];
}

const ML_TRAIN_PUBLISH_TEMPLATE = 'ml.train-publish';

function sendError(res: Response, status: number, error: string): void {
  res.status(status).json({ error });
}

function asObject(value: unknown): Record<string, unknown> {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function sortJson(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(sortJson);
  }
  if (value && typeof value === 'object') {
    return Object.keys(value as Record<string, unknown>)
      .sort()
      .reduce<Record<string, unknown>>((acc, key) => {
        acc[key] = sortJson((value as Record<string, unknown>)[key]);
        return acc;
      }, {});
  }
  return value;
}

function stableJson(value: unknown): string {
  return JSON.stringify(sortJson(value));
}

function readTemplate(name: string): TemplateDefinition {
  const templatePath = path.resolve(__dirname, '..', 'templates', `${name}.yaml`);
  const raw = fs.readFileSync(templatePath, 'utf8');
  const parsed = parse(raw) as Partial<TemplateDefinition>;

  if (!parsed.name || !Array.isArray(parsed.steps)) {
    throw new Error(`Template ${name} must include name and steps[]`);
  }

  return {
    name: parsed.name,
    description: parsed.description,
    metadata: asObject(parsed.metadata),
    steps: parsed.steps,
  };
}

async function ensureTemplateDefinition(name: string) {
  const template = readTemplate(name);
  const latest = await prisma.trussDefinition.findFirst({
    where: { name: template.name },
    orderBy: { version: 'desc' },
  });

  if (latest && stableJson(latest.steps) === stableJson(template.steps)) {
    return latest;
  }

  return prisma.trussDefinition.create({
    data: {
      name: template.name,
      description: template.description,
      version: (latest?.version ?? 0) + 1,
      steps: template.steps as any,
      metadata: template.metadata as any,
    },
  });
}

async function createRun(definitionId: string, input: Record<string, unknown>) {
  const run = await prisma.trussRun.create({
    data: {
      definitionId,
      input: input as any,
    },
  });

  await startRun(run.id);
  return prisma.trussRun.findUnique({
    where: { id: run.id },
    include: { definition: true, stepRuns: { orderBy: { createdAt: 'asc' } } },
  });
}

router.get('/definitions', async (req: Request, res: Response) => {
  const allVersions = req.query.allVersions === 'true';
  const definitions = await prisma.trussDefinition.findMany({
    orderBy: [{ name: 'asc' }, { version: 'desc' }],
  });

  if (allVersions) {
    res.json({ definitions });
    return;
  }

  const latestByName = new Map<string, (typeof definitions)[number]>();
  for (const definition of definitions) {
    if (!latestByName.has(definition.name)) {
      latestByName.set(definition.name, definition);
    }
  }

  res.json({ definitions: Array.from(latestByName.values()) });
});

router.post('/definitions', async (req: Request, res: Response) => {
  const { name, description, steps, metadata, enabled } = req.body ?? {};
  if (!name || !Array.isArray(steps)) {
    sendError(res, 400, 'name and steps[] are required');
    return;
  }

  const latest = await prisma.trussDefinition.findFirst({
    where: { name },
    orderBy: { version: 'desc' },
  });

  const definition = await prisma.trussDefinition.create({
    data: {
      name,
      description,
      version: (latest?.version ?? 0) + 1,
      steps: steps as any,
      metadata: asObject(metadata) as any,
      enabled: enabled ?? true,
    },
  });

  res.status(201).json(definition);
});

router.get('/definitions/:id', async (req: Request, res: Response) => {
  const definition = await prisma.trussDefinition.findUnique({
    where: { id: req.params.id },
  });

  if (!definition) {
    sendError(res, 404, 'Truss definition not found');
    return;
  }

  res.json(definition);
});

router.post('/definitions/:id/runs', async (req: Request, res: Response) => {
  const definition = await prisma.trussDefinition.findUnique({
    where: { id: req.params.id },
  });

  if (!definition) {
    sendError(res, 404, 'Truss definition not found');
    return;
  }

  if (!definition.enabled) {
    sendError(res, 409, 'Truss definition is disabled');
    return;
  }

  const run = await createRun(definition.id, asObject(req.body?.input ?? req.body));
  res.status(201).json(run);
});

router.post('/templates/ml.train-publish', async (req: Request, res: Response) => {
  const definition = await ensureTemplateDefinition(ML_TRAIN_PUBLISH_TEMPLATE);
  const run = await createRun(definition.id, asObject(req.body?.input ?? req.body));

  res.status(201).json({
    definition: {
      id: definition.id,
      name: definition.name,
      version: definition.version,
    },
    run,
  });
});

router.get('/runs', async (_req: Request, res: Response) => {
  const runs = await prisma.trussRun.findMany({
    orderBy: { createdAt: 'desc' },
    include: {
      definition: true,
      stepRuns: { orderBy: { createdAt: 'asc' } },
    },
  });

  res.json({ runs });
});

router.get('/runs/:id', async (req: Request, res: Response) => {
  await reconcileRun(req.params.id);
  const run = await prisma.trussRun.findUnique({
    where: { id: req.params.id },
    include: {
      definition: true,
      stepRuns: { orderBy: { createdAt: 'asc' } },
    },
  });

  if (!run) {
    sendError(res, 404, 'Truss run not found');
    return;
  }

  res.json(run);
});

router.get('/runs/:id/steps', async (req: Request, res: Response) => {
  await reconcileRun(req.params.id);
  const run = await prisma.trussRun.findUnique({
    where: { id: req.params.id },
  });

  if (!run) {
    sendError(res, 404, 'Truss run not found');
    return;
  }

  const steps = await prisma.trussStepRun.findMany({
    where: { runId: req.params.id },
    orderBy: { createdAt: 'asc' },
  });

  res.json({ steps });
});

router.post('/runs/:id/cancel', async (req: Request, res: Response) => {
  const run = await prisma.trussRun.findUnique({
    where: { id: req.params.id },
  });

  if (!run) {
    sendError(res, 404, 'Truss run not found');
    return;
  }

  if (['completed', 'failed', 'cancelled'].includes(run.status)) {
    sendError(res, 409, `Truss run is already ${run.status}`);
    return;
  }

  const activeSteps = await prisma.trussStepRun.findMany({
    where: {
      runId: req.params.id,
      status: { in: ['queued', 'running', 'waiting'] },
    },
  });

  const updated = await prisma.trussRun.update({
    where: { id: req.params.id },
    data: {
      status: 'cancelled',
      completedAt: new Date(),
    },
  });

  await prisma.trussStepRun.updateMany({
    where: {
      runId: req.params.id,
      status: { in: ['queued', 'running', 'waiting'] },
    },
    data: {
      status: 'cancelled',
      completedAt: new Date(),
    },
  });

  await Promise.all(
    activeSteps.map((step) => publishTrussStepEvent('cancelled', req.params.id, step.stepId))
  );
  await publishTrussRunEvent('cancelled', req.params.id, {
    cancelledSteps: activeSteps.length,
  });

  res.json(updated);
});

export default router;

