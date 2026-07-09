from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime
import asyncio

app = FastAPI(title="Truss API", version="2.0.0")

class TaskInput(BaseModel):
    name: str
    workflow_id: Optional[str] = None
    input_data: Optional[Dict[str, Any]] = None
    dependencies: Optional[List[str]] = []
    priority: Optional[int] = 0

class TaskUpdate(BaseModel):
    status: str
    output_data: Optional[Dict[str, Any]] = None
    error: Optional[str] = None

class WorkflowDefinition(BaseModel):
    id: str
    name: str
    stages: List[Dict[str, Any]]
    retry_policy: Optional[Dict[str, Any]] = None
    timeout: Optional[int] = 3600

class Task:
    def __init__(self, id: str, name: str, status: str, workflow_id: Optional[str] = None):
        self.id = id
        self.name = name
        self.status = status
        self.workflow_id = workflow_id
        self.input_data = {}
        self.output_data = {}
        self.created_at = datetime.utcnow().isoformat()
        self.updated_at = datetime.utcnow().isoformat()
        self.dependencies = []
        self.version = 1

class Workflow:
    def __init__(self, id: str, name: str, stages: List[Dict[str, Any]]):
        self.id = id
        self.name = name
        self.stages = stages
        self.status = "pending"
        self.created_at = datetime.utcnow().isoformat()
        self.current_stage = 0

tasks_db: Dict[str, Task] = {}
workflows_db: Dict[str, Workflow] = {}
task_counter = 0

@app.get("/")
async def root():
    return {"service": "deepiri-truss", "version": "2.0.0"}

@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "service": "deepiri-truss",
        "capabilities": [
            "task-lifecycle",
            "task-versioning",
            "dependency-graphs",
            "workflow-definition",
            "fastapi-modernization"
        ],
        "timestamp": datetime.utcnow().isoformat()
    }

@app.post("/task")
async def create_task(task_input: TaskInput, background_tasks: BackgroundTasks):
    global task_counter
    task_counter += 1
    
    task_id = f"task-{task_counter}"
    
    task = Task(
        id=task_id,
        name=task_input.name,
        status="pending",
        workflow_id=task_input.workflow_id
    )
    task.input_data = task_input.input_data or {}
    task.dependencies = task_input.dependencies or []
    
    tasks_db[task_id] = task
    
    if task.dependencies:
        background_tasks.add_task(check_dependencies, task_id)
    
    return {"task_id": task_id, "status": "pending"}

@app.get("/task/{task_id}")
async def get_task(task_id: str):
    if task_id not in tasks_db:
        raise HTTPException(status_code=404, detail="Task not found")
    task = tasks_db[task_id]
    return {
        "id": task.id,
        "name": task.name,
        "status": task.status,
        "workflow_id": task.workflow_id,
        "version": task.version,
        "created_at": task.created_at,
        "updated_at": task.updated_at
    }

@app.patch("/task/{task_id}")
async def update_task(task_id: str, task_update: TaskUpdate):
    if task_id not in tasks_db:
        raise HTTPException(status_code=404, detail="Task not found")
    
    task = tasks_db[task_id]
    task.status = task_update.status
    task.output_data = task_update.output_data or {}
    task.updated_at = datetime.utcnow().isoformat()
    
    if task_update.status == "completed":
        task.version += 1
        await notify_dependents(task_id)
    
    return {"task_id": task_id, "status": task.status}

@app.get("/task/{task_id}/version")
async def get_task_versions(task_id: str):
    if task_id not in tasks_db:
        raise HTTPException(status_code=404, detail="Task not found")
    
    task = tasks_db[task_id]
    return {
        "current_version": task.version,
        "history": [
            {"version": task.version, "updated_at": task.updated_at}
        ]
    }

@app.get("/task/{task_id}/graph")
async def get_dependency_graph(task_id: str):
    if task_id not in tasks_db:
        raise HTTPException(status_code=404, detail="Task not found")
    
    task = tasks_db[task_id]
    return {
        "task_id": task_id,
        "dependencies": task.dependencies,
        "dependents": get_dependents(task_id)
    }

@app.post("/workflow")
async def create_workflow(workflow_def: WorkflowDefinition):
    workflow = Workflow(
        id=workflow_def.id,
        name=workflow_def.name,
        stages=workflow_def.stages
    )
    workflows_db[workflow_def.id] = workflow
    return {"workflow_id": workflow_def.id, "status": "created"}

@app.get("/workflow/{workflow_id}")
async def get_workflow(workflow_id: str):
    if workflow_id not in workflows_db:
        raise HTTPException(status_code=404, detail="Workflow not found")
    
    wf = workflows_db[workflow_id]
    return {
        "id": wf.id,
        "name": wf.name,
        "status": wf.status,
        "current_stage": wf.current_stage,
        "stages": wf.stages
    }

@app.post("/workflow/{workflow_id}/execute")
async def execute_workflow(workflow_id: str, background_tasks: BackgroundTasks):
    if workflow_id not in workflows_db:
        raise HTTPException(status_code=404, detail="Workflow not found")
    
    background_tasks.add_task(run_workflow, workflow_id)
    return {"workflow_id": workflow_id, "status": "executing"}

def get_dependents(task_id: str) -> List[str]:
    return [
        tid for tid, task in tasks_db.items()
        if task_id in task.dependencies
    ]

async def check_dependencies(task_id: str):
    task = tasks_db[task_id]
    for dep_id in task.dependencies:
        if dep_id in tasks_db:
            dep_task = tasks_db[dep_id]
            if dep_task.status != "completed":
                task.status = "blocked"
                return
    task.status = "ready"

async def notify_dependents(completed_task_id: str):
    for dependent_id in get_dependents(completed_task_id):
        if dependent_id in tasks_db:
            await check_dependencies(dependent_id)

async def run_workflow(workflow_id: str):
    wf = workflows_db[workflow_id]
    wf.status = "running"
    
    for stage in wf.stages:
        wf.current_stage += 1
        await asyncio.sleep(0.1)
    
    wf.status = "completed"

@app.get("/capabilities")
async def get_capabilities():
    return {
        "service": "deepiri-truss",
        "version": "2.0.0",
        "capabilities": {
            "task": {
                "description": "Task lifecycle management",
                "endpoints": ["/task", "/task/{id}", "/task/{id}/version"]
            },
            "workflow": {
                "description": "Workflow definition and execution",
                "endpoints": ["/workflow", "/workflow/{id}/execute"]
            },
            "dependency": {
                "description": "Dependency graph tracking",
                "endpoints": ["/task/{id}/graph"]
            }
        }
    }