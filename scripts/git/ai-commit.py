#!/usr/bin/env python3
"""
AI-Powered Git Commit Script for Deepiri Platform
Analyzes git diffs, groups into logical commits, generates detailed commit messages.
Handles: recursive repo detection, submodule support, segmented commits, interactive selection.

Performance / Ollama (optional env):
  OLLAMA_KEEP_ALIVE                — keep model in VRAM between runs (default 30m)
  OLLAMA_COMMIT_NUM_PREDICT        — max output tokens on full path (default 576)
  OLLAMA_COMMIT_NUM_PREDICT_SIMPLE — max output tokens on fast path (default 256)
  AI_COMMIT_SIMPLE_MAX_FILES       — fast path when <= N files and no conflict markers (default 5)
  AI_COMMIT_MAX_DIFF_CHARS         — diff char cap, full path (default 65536)
  AI_COMMIT_MAX_DIFF_CHARS_SIMPLE  — diff char cap, fast path (default 2000 * num_files)

CRITICAL: Never send num_ctx/num_batch/num_gpu in per-request Ollama options.
Those are model-init params — changing them causes a full model reload (~30-60s).

CLI: --full-auto or --full — all repos (submodules first), auto model pick, commit all, push, generate PR, create/comment PR without prompts.
"""
import asyncio
import json
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from functools import lru_cache
from typing import Optional
from deepiri_ollama.runtime import check

try:
    import httpx
except ImportError:
    print("Error: httpx library required. Install with: pip install httpx")
    sys.exit(1)


def get_os_type() -> str:
    if sys.platform == "darwin":
        return "mac"
    if sys.platform == "win32" or "microsoft" in os.uname().release.lower():
        return "windows"
    return "linux"


def is_ollama_running(base_url="http://localhost:11434"):
    result = asyncio.run(check(base_url))
    return result.get("running", False)


def start_ollama(root_path: str, base_url: str) -> bool:
    os_type = get_os_type()
    
    if is_ollama_running(base_url):
        return True
    
    if os_type == "mac":
        print(f"{Colors.YELLOW}Ollama not running. Starting with 'ollama serve'...{Colors.NC}")
        try:
            subprocess.Popen(["ollama", "serve"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            import time
            for _ in range(15):
                time.sleep(1)
                if is_ollama_running(base_url):
                    print(f"{Colors.GREEN}✓ Ollama started{Colors.NC}")
                    return True
            print(f"{Colors.RED}✗ Failed to start Ollama{Colors.NC}")
            return False
        except Exception as e:
            print(f"{Colors.RED}✗ Failed to start Ollama: {e}{Colors.NC}")
            return False
    else:
        compose_file = os.path.join(root_path, "docker-compose.dev.yml")
        if not os.path.isfile(compose_file):
            compose_file = os.path.join(root_path, "docker-compose.yml")
        
        print(f"{Colors.YELLOW}Ollama not running. Starting with docker compose...{Colors.NC}")
        try:
            result = subprocess.run(
                ["docker", "compose", "-f", compose_file, "up", "-d", "ollama"],
                cwd=root_path,
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                print(f"{Colors.RED}✗ Docker compose failed: {result.stderr}{Colors.NC}")
                return False
            
            import time
            for _ in range(30):
                time.sleep(1)
                if is_ollama_running(base_url):
                    print(f"{Colors.GREEN}✓ Ollama started (docker){Colors.NC}")
                    return True
            print(f"{Colors.YELLOW}⚠ Ollama container may still be starting...{Colors.NC}")
            return True
        except Exception as e:
            print(f"{Colors.RED}✗ Failed to start Ollama: {e}{Colors.NC}")
            return False


def find_check_ollama_script(root_path: str) -> str | None:
    env_override = os.getenv("OLLAMA_SCRIPTS_ROOT")
    if env_override:
        script_path = os.path.join(env_override, "check-ollama-models.sh")
        if os.path.isfile(script_path):
            return script_path

    search_paths = [
        os.path.join(root_path, "diri-cyrex", "scripts", "llm", "check-ollama-models.sh"),
        os.path.join(root_path, "scripts", "llm", "check-ollama-models.sh"),
        os.path.join(os.path.dirname(__file__), "..", "llm", "check-ollama-models.sh"),
        os.path.join(os.path.dirname(__file__), "..", "scripts", "llm", "check-ollama-models.sh"),
    ]

    for path in search_paths:
        if os.path.isfile(path):
            return path

    current = root_path
    for _ in range(5):
        parent = os.path.dirname(current)
        if parent == current:
            break
        for sibling in ["elomix-nexus", "elomix-platform", "deepiri"]:
            for subpath in ["scripts/llm", "llm/scripts", "diri-cyrex/scripts/llm"]:
                script_path = os.path.join(parent, sibling, subpath, "check-ollama-models.sh")
                if os.path.isfile(script_path):
                    return script_path
        current = parent

    return None


class Colors:
    GREEN = "\033[0;32m"
    RED = "\033[0;31m"
    BOLD = "\033[1m"
    YELLOW = "\033[1;33m"
    BLUE = "\033[0;34m"
    CYAN = "\033[0;36m"
    MAGENTA = "\033[0;35m"
    NC = "\033[0m"


class Spinner:
    FRAMES = ["|", "/", "-", "\\"]
    THINKING = [
        "Thinking",
        "Thinking.",
        "Thinking..",
        "Thinking...",
    ]

    def __init__(self, text: str = ""):
        self.text = text
        self._task: asyncio.Task | None = None
        self._running = False
        self._col_width = 0
        self._start_time = None

    async def _spin(self):
        import time
        self._start_time = time.time()
        i = 0
        while self._running:
            frame = self.FRAMES[i % len(self.FRAMES)]
            elapsed = int(time.time() - self._start_time)
            time_str = f" [{elapsed}s]"
            line = f"  {Colors.CYAN}{frame}{Colors.NC} {self.text}{time_str}"
            pad = max(0, self._col_width - len(self.text) - 10)
            sys.stdout.write(f"\r{line}{' ' * pad}")
            sys.stdout.flush()
            self._col_width = max(self._col_width, len(self.text) + 10)
            await asyncio.sleep(0.15)
            i += 1

    async def __aenter__(self):
        self._running = True
        self._task = asyncio.create_task(self._spin())
        print(f"  > {self.text}", flush=True)
        return self

    async def __aexit__(self, *_):
        self._running = False
        if self._task:
            await self._task
        sys.stdout.write(f"\r{' ' * (self._col_width + 20)}\r")
        sys.stdout.flush()

    def update(self, text: str):
        self.text = text


def is_git_repo(path: str) -> bool:
    """Check if path is a git repo (dir or file pointing to worktree)"""
    return os.path.isdir(os.path.join(path, ".git")) or os.path.isfile(os.path.join(path, ".git"))


def find_script_git_root() -> str:
    """Find the first git repo containing this script, searching upward"""
    script_path = os.path.dirname(os.path.abspath(__file__))
    current = script_path

    while True:
        if is_git_repo(current):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            break
        current = parent

    return os.getcwd()


def parse_gitmodules(root_path: str) -> list[str]:
    """Parse .gitmodules to extract submodule paths"""
    submodule_paths = []
    gitmodules_path = os.path.join(root_path, ".gitmodules")

    if not os.path.isfile(gitmodules_path):
        return submodule_paths

    try:
        with open(gitmodules_path, "r") as f:
            content = f.read()

        for line in content.split("\n"):
            line = line.strip()
            if line.startswith("path") and "=" in line:
                path = line.split("=", 1)[1].strip()
                if path and path not in submodule_paths:
                    submodule_paths.append(path)
    except Exception:
        pass

    return submodule_paths


def find_git_repos(root_path: str, search_parents: bool = False, max_depth: int = 3) -> list[dict]:
    """Find all git repos: root, submodules, and sibling repos in parent directories"""
    repos = []
    root_abs = os.path.abspath(root_path)

    root_name = os.path.basename(root_abs) or root_abs
    if is_git_repo(root_abs):
        repos.append({"path": root_abs, "name": root_name, "is_submodule": False})

    submodule_paths = parse_gitmodules(root_abs)
    submodule_abs_paths = set()
    for subpath in submodule_paths:
        full_path = os.path.join(root_abs, subpath)
        if is_git_repo(full_path):
            repos.append({
                "path": full_path,
                "name": os.path.basename(subpath),
                "is_submodule": True,
            })
            submodule_abs_paths.add(os.path.abspath(full_path))

    try:
        result = subprocess.run(
            ["git", "submodule", "status"],
            cwd=root_abs,
            capture_output=True,
            text=True,
        )

        if result.returncode == 0:
            for line in result.stdout.strip().split("\n"):
                if line:
                    parts = line.split()
                    if len(parts) >= 2:
                        submodule_path = parts[1]
                        full_path = os.path.join(root_abs, submodule_path)
                        full_path_abs = os.path.abspath(full_path)
                        if is_git_repo(full_path) and full_path_abs not in submodule_abs_paths:
                            repos.append({
                                "path": full_path_abs,
                                "name": os.path.basename(submodule_path),
                                "is_submodule": True,
                            })
                            submodule_abs_paths.add(full_path_abs)
    except Exception:
        pass

    return repos


def find_sibling_repos(root_path: str, max_depth: int = 3) -> list[dict]:
    """Search parent directories for sibling git repos"""
    sibling_repos = []
    root_abs = os.path.abspath(root_path)

    current_path = root_abs
    for _ in range(max_depth):
        parent_dir = os.path.dirname(current_path)
        if parent_dir == current_path:
            break

        try:
            if os.path.isdir(parent_dir):
                for entry in os.listdir(parent_dir):
                    entry_path = os.path.join(parent_dir, entry)
                    if os.path.isdir(entry_path) and is_git_repo(entry_path):
                        entry_abs = os.path.abspath(entry_path)
                        if entry_abs != root_abs:
                            sibling_repos.append({
                                "path": entry_abs,
                                "name": entry,
                                "is_submodule": False,
                                "is_sibling": True,
                            })
        except Exception:
            pass

        current_path = parent_dir

    return sibling_repos


def get_git_diff(repo_path: str) -> str:
    """Get all unstaged git changes"""
    try:
        result = subprocess.run(
            ["git", "diff"],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        return result.stdout
    except Exception:
        return ""


def get_git_status(repo_path: str) -> str:
    """Get git status"""
    try:
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        return result.stdout
    except Exception:
        return ""


def get_untracked_files(repo_path: str) -> list[str]:
    """Return untracked files from git status --porcelain"""
    try:
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        untracked = []
        for line in result.stdout.splitlines():
            if line.startswith("?? "):
                path = line[3:].strip()
                full = os.path.join(repo_path, path)
                if os.path.isfile(full):
                    untracked.append(path)
                elif os.path.isdir(full):
                    for root, _, filenames in os.walk(full):
                        for fname in filenames:
                            abs_path = os.path.join(root, fname)
                            rel = os.path.relpath(abs_path, repo_path)
                            untracked.append(rel)
        return untracked
    except Exception:
        return []


def get_new_file_diff(repo_path: str, file_path: str) -> str:
    """Generate a diff-like snippet for an untracked file by reading its content"""
    try:
        full_path = os.path.join(repo_path, file_path)
        with open(full_path, "r", errors="replace") as f:
            content = f.read(8000)
        lines = content.splitlines()
        added = "\n".join(f"+{line}" for line in lines[:200])
        return f"diff --git a/{file_path} b/{file_path}\nnew file\n--- /dev/null\n+++ b/{file_path}\n{added}"
    except Exception:
        return ""


def parse_changed_files(diff_output: str) -> list[dict]:
    """Parse diff output to extract changed files, hunks, and submodule pointers"""
    files = []
    current_file = None
    current_hunks = []
    current_meta: dict = {}
    hunk_num = 0

    for line in diff_output.split("\n"):
        if line.startswith("diff --git"):
            if current_file:
                files.append({"file": current_file, "hunks": current_hunks, **current_meta})
            match = re.search(r"b/(.+)", line)
            current_file = match.group(1) if match else "unknown"
            current_hunks = []
            current_meta = {}
            hunk_num = 0
        elif re.match(r"^index [0-9a-f]+\.\.[0-9a-f]+ 160000", line):
            sha_match = re.match(r"^index ([0-9a-f]+)\.\.([0-9a-f]+)", line)
            if sha_match:
                current_meta["is_submodule_pointer"] = True
                current_meta["old_sha"] = sha_match.group(1)
                current_meta["new_sha"] = sha_match.group(2)
        elif line.startswith("@@"):
            hunk_num += 1
            match = re.match(r"@@ -(\d+),?(\d*) \+(\d+),?(\d*) @@(.*)", line)
            if match:
                current_hunks.append({
                    "hunk_num": hunk_num,
                    "old_start": int(match.group(1)),
                    "old_count": int(match.group(2) or 1),
                    "new_start": int(match.group(3)),
                    "new_count": int(match.group(4) or 1),
                    "header": line,
                })

    if current_file:
        files.append({"file": current_file, "hunks": current_hunks, **current_meta})

    return files


def _check_submodule_dirty(repo_path: str, subpath: str) -> dict | None:
    full_path = os.path.join(repo_path, subpath)
    if not os.path.isdir(full_path):
        return None
    if not os.path.isdir(os.path.join(full_path, ".git")) and not os.path.isfile(os.path.join(full_path, ".git")):
        return None
    try:
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=full_path, capture_output=True, text=True,
        )
        if result.stdout.strip():
            lines = result.stdout.strip().splitlines()
            modified = sum(1 for l in lines if not l.startswith("??"))
            untracked = sum(1 for l in lines if l.startswith("??"))
            if modified > 0 or untracked > 0:
                return {"path": subpath, "full_path": full_path, "modified": modified, "untracked": untracked}
    except Exception:
        # Best-effort check: if git status fails for this submodule, ignore it and treat as not dirty.
        pass
    return None


def get_dirty_submodules(repo_path: str, submodule_paths: list[str]) -> list[dict]:
    """Return submodules that have uncommitted changes — checks all in parallel."""
    if not submodule_paths:
        return []
    with ThreadPoolExecutor(max_workers=min(8, len(submodule_paths))) as pool:
        results = pool.map(lambda sp: _check_submodule_dirty(repo_path, sp), submodule_paths)
    return [r for r in results if r is not None]


_http_client: Optional[httpx.AsyncClient] = None


def _get_http_client() -> httpx.AsyncClient:
    global _http_client
    if _http_client is None or _http_client.is_closed:
        _http_client = httpx.AsyncClient(
            timeout=180.0,
            limits=httpx.Limits(max_keepalive_connections=5, max_connections=10),
        )
    return _http_client


def _truncate_diff_for_commit_analysis(diff: str, *, max_chars: int | None = None) -> str:
    """Cap diff to max_chars (default from env / 65536). Pass a smaller limit for fast path."""
    limit = max_chars if max_chars is not None else int(os.getenv("AI_COMMIT_MAX_DIFF_CHARS", "65536"))
    if len(diff) <= limit:
        return diff
    half = (limit - 240) // 2
    omitted = len(diff) - limit
    return (
        diff[:half]
        + f"\n\n... [diff truncated: {omitted} chars omitted for speed; "
        f"full diff was {len(diff)} chars — file list above is complete] ...\n\n"
        + diff[-half:]
    )


def _diff_has_merge_conflict_markers(diff: str) -> bool:
    """True if diff contains unresolved merge conflict markers — use full segmentation path."""
    if not diff:
        return False
    return bool(
        re.search(r"^<<<<<<< ", diff, re.MULTILINE)
        or re.search(r"^>>>>>>> ", diff, re.MULTILINE)
        or re.search(r"^=======$", diff, re.MULTILINE)
    )


def _ollama_sampling_options(*, simple_path: bool) -> dict:
    """Sampling-only options. NEVER include model-init params (num_ctx, num_batch, num_gpu) —
    Ollama reloads the entire model (~30-60s) whenever any of those change between requests.
    Let the model keep whatever context size it was loaded with.
    """
    if simple_path:
        num_predict = int(os.getenv("OLLAMA_COMMIT_NUM_PREDICT_SIMPLE", "256"))
    else:
        num_predict = int(os.getenv("OLLAMA_COMMIT_NUM_PREDICT", "576"))

    return {
        "temperature": 0.2,
        "top_k": 40,
        "top_p": 0.9,
        "num_predict": num_predict,
    }


def _normalise_commit_body(body: object) -> str:
    """Model JSON may use a string or list of bullet strings for body."""
    if body is None:
        return ""
    if isinstance(body, list):
        return "\n".join(str(x).strip() for x in body if str(x).strip())
    return str(body)


def _commit_body_lines(body: object) -> list[str]:
    return _normalise_commit_body(body).splitlines()


def _normalise_commits_from_parsed(
    parsed: dict,
    files: list[dict],
    *,
    debug: str | None,
) -> list[dict] | None:
    """Extract commits list from model JSON and filter to known file paths."""
    commits = None
    for key in ("commits", "commit_segmentation_plan", "commit_plan", "segments"):
        val = parsed.get(key)
        if isinstance(val, list) and val:
            commits = val
            break

    if not commits:
        return None

    valid_paths = {f["file"] for f in files}
    normalised: list[dict] = []
    seen_paths: set[str] = set()
    for c in commits:
        raw_files = c.get("files") or c.get("file_paths") or c.get("changed_files") or []
        actual_files: list[str] = []
        for f in raw_files:
            if f in valid_paths and f not in seen_paths:
                actual_files.append(f)
                seen_paths.add(f)
        if actual_files:
            normalised.append({
                "description": c.get("subject") or c.get("description") or c.get("commit_message") or "Update files",
                "subject": c.get("subject") or c.get("description") or c.get("commit_message") or "Update files",
                "body": _normalise_commit_body(c.get("body") or c.get("reasoning")),
                "files": actual_files,
            })

    if not normalised:
        return None

    covered = set()
    for c in normalised:
        covered.update(c["files"])
    missing = valid_paths - covered
    if missing:
        if debug:
            print(f"{Colors.YELLOW}[DEBUG] Model omitted files {missing}; merging into last commit.{Colors.NC}")
        if normalised:
            normalised[-1]["files"] = list(dict.fromkeys(normalised[-1]["files"] + sorted(missing)))
        else:
            return None

    if debug:
        print(f"{Colors.GREEN}[DEBUG] Parsed {len(normalised)} commit(s){Colors.NC}")
    return normalised


def _parse_commit_plan_json(response: str, files: list[dict], *, debug: str | None) -> list[dict] | None:
    """Parse JSON commit plan; tolerant of minor whitespace. Returns None if unusable."""
    text = (response or "").strip()
    if not text:
        return None

    parsed: dict | None = None
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        cleaned = re.sub(r"```(?:json)?\s*", "", text).strip()
        try:
            brace_start = cleaned.find("{")
            if brace_start != -1:
                parsed, _ = json.JSONDecoder().raw_decode(cleaned, brace_start)
        except json.JSONDecodeError:
            return None

    if not isinstance(parsed, dict):
        return None
    return _normalise_commits_from_parsed(parsed, files, debug=debug)


async def send_to_ollama(
    base_url: str,
    model: str,
    prompt: str,
    system: str = "",
    *,
    options: dict | None = None,
    keep_alive: str | None = None,
) -> str:
    """Send prompt to Ollama and return the full response (streamed internally for lower latency).

    keep_alive: how long to keep the model in VRAM (default from env or 30m).
    NOTE: do NOT pass model-init params (num_ctx, num_batch, num_gpu) via options on every call —
    Ollama reloads the model when those change, adding 30-60s overhead.
    """
    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})

    payload: dict = {
        "model": model,
        "messages": messages,
        "stream": True,
    }
    ka = keep_alive if keep_alive is not None else os.getenv("OLLAMA_KEEP_ALIVE", "30m")
    if ka:
        payload["keep_alive"] = ka
    if options:
        payload["options"] = options

    prompt_chars = len(system) + len(prompt)

    try:
        client = _get_http_client()
        tokens: list[str] = []
        done_chunk: dict = {}
        async with client.stream("POST", f"{base_url}/api/chat", json=payload) as response:
            response.raise_for_status()
            async for line in response.aiter_lines():
                if not line:
                    continue
                chunk = json.loads(line)
                token = chunk.get("message", {}).get("content", "")
                if token:
                    tokens.append(token)
                if chunk.get("done"):
                    done_chunk = chunk
                    break

        _print_ollama_timing(done_chunk, prompt_chars, len(tokens))
        return "".join(tokens)
    except Exception as e:
        print(f"{Colors.RED}Error sending request to Ollama: {e}{Colors.NC}")
        sys.exit(1)


def _print_ollama_timing(done: dict, prompt_chars: int, num_response_chunks: int) -> None:
    """Print Ollama timing breakdown from the done chunk. Always shown — this is critical perf data."""
    if not done:
        return
    load_ns = done.get("load_duration", 0)
    prompt_ns = done.get("prompt_eval_duration", 0)
    eval_ns = done.get("eval_duration", 0)
    total_ns = done.get("total_duration", 0)
    prompt_tokens = done.get("prompt_eval_count", 0)
    eval_tokens = done.get("eval_count", 0)

    load_s = load_ns / 1e9
    prompt_s = prompt_ns / 1e9
    eval_s = eval_ns / 1e9
    total_s = total_ns / 1e9

    prompt_tps = prompt_tokens / prompt_s if prompt_s > 0 else 0
    eval_tps = eval_tokens / eval_s if eval_s > 0 else 0

    parts = [f"total={total_s:.1f}s"]
    if load_s > 0.5:
        parts.append(f"load={load_s:.1f}s")
    parts.append(f"prompt={prompt_s:.1f}s ({prompt_tokens}tok, {prompt_tps:.0f}t/s)")
    parts.append(f"gen={eval_s:.1f}s ({eval_tokens}tok, {eval_tps:.0f}t/s)")
    parts.append(f"input~{prompt_chars}chars")

    print(f"  {Colors.YELLOW}⏱{Colors.NC}  {' | '.join(parts)}")


_SIMPLE_COMMIT_SYSTEM = """Git commit assistant. Output ONLY JSON, no markdown:
{"commits":[{"subject":"verb-first ≤100chars; name real class/fn/config + scope (module or area)","body":"- symbol or file: what changed and briefly why\\n- ...","files":["exact/path/from/list"]}]}
Rules: partition every file into exactly one commit; subjects start with Add/Fix/Refactor/Remove/Implement/Extract; body 3-5 bullets for non-trivial work (2 if tiny); avoid vague one-word labels; omit body only if the subject is fully specific; split into multiple commits when concerns are independent (CI vs app, docs vs code)."""


async def _generate_simple_commit(
    base_url: str,
    model: str,
    repo_name: str,
    diff_output: str,
    files: list[dict],
) -> list[dict]:
    """Fast path: one Ollama call, smaller prompt — still allows multiple commits if justified."""
    files_summary = "\n".join(f["file"] for f in files)
    simple_diff_cap = int(os.getenv("AI_COMMIT_MAX_DIFF_CHARS_SIMPLE", str(2000 * max(len(files), 1))))
    diff_for_model = _truncate_diff_for_commit_analysis(diff_output or "", max_chars=simple_diff_cap)
    prompt = f"""Repo: {repo_name}
Files you must cover ({len(files)}), use these exact paths:
{files_summary}

Diff:
{diff_for_model or "(no diff)"}

Output JSON only."""

    opts = _ollama_sampling_options(simple_path=True)

    response = await send_to_ollama(
        base_url,
        model,
        prompt,
        system=_SIMPLE_COMMIT_SYSTEM,
        options=opts,
    )

    debug = os.getenv("AI_COMMIT_DEBUG")
    if debug:
        print(f"\n{Colors.YELLOW}[DEBUG] Raw model response (simple path):{Colors.NC}\n{response}\n")

    parsed = _parse_commit_plan_json(response, files, debug=debug)
    if parsed:
        return parsed

    print(f"{Colors.YELLOW}Simple path parse failed — retrying with full segmentation prompt.{Colors.NC}")
    return await _analyze_and_generate_commits_full(
        base_url, model, repo_name, diff_output, files,
    )


async def _analyze_and_generate_commits_full(
    base_url: str,
    model: str,
    repo_name: str,
    diff_output: str,
    files: list[dict],
) -> list[dict]:
    """Full segmentation prompt for larger changesets, merge conflicts, or simple-path fallback."""

    system_prompt = """You are a git commit assistant. Given changed files and their diff, group them into logical commits and write a specific commit message for each group.

Return ONLY raw JSON, no markdown, no explanation. Schema:
{"commits":[{"subject":"<verb-first, ≤100 chars, name real classes/methods/configs + area/feature when helpful>","body":"- <thing>: what changed (and briefly why if non-obvious)\n- ...","files":["path/a.py"]}]}

Grouping rules:
- Every file must appear in exactly one commit
- Dockerfile/CI config = own commit; docs/ = own commit
- Group files in the same directory serving the same purpose
- 6+ files must produce 3+ commits
- If the diff contains merge conflict markers or conflict resolutions, group by concern and describe how conflicts were resolved in the body

Subject rules:
- Name the actual class, method, function, or config key that changed; add scope (module/path segment) when it disambiguates
- Start with a verb: Add, Fix, Refactor, Remove, Implement, Enforce, Extract
- No conventional commit prefix (no "feat:", "fix:", etc.)
- Bad: "Refactors rate limiter" — Good: "Add RateLimitMiddleware with Redis token-bucket"

Body rules:
- 3-5 bullet points for non-trivial commits (2-3 if the change is tiny); each names an exact method/class/field/path and what changed; add a short "why" when it helps reviewers
- For conflict resolution, name files/hunks and what was kept or merged
- Omit body only when the subject already states every important detail (rare)"""

    files_summary = "\n".join(f["file"] for f in files)
    diff_for_model = _truncate_diff_for_commit_analysis(diff_output or "")
    prompt = f"""Repo: {repo_name}
Files changed ({len(files)}):
{files_summary}

Diff:
{diff_for_model or "(no diff)"}

Output only JSON."""

    opts = _ollama_sampling_options(simple_path=False)

    response = await send_to_ollama(
        base_url,
        model,
        prompt,
        system=system_prompt,
        options=opts,
    )

    debug = os.getenv("AI_COMMIT_DEBUG")
    if debug:
        print(f"\n{Colors.YELLOW}[DEBUG] Raw model response:{Colors.NC}\n{response}\n")

    parsed = _parse_commit_plan_json(response, files, debug=debug)
    if parsed:
        return parsed

    print(f"{Colors.RED}Model returned unparseable response — falling back to single commit.{Colors.NC}")
    print(f"{Colors.YELLOW}Tip: set AI_COMMIT_DEBUG=1 to see raw model output.{Colors.NC}")

    file_list = [f["file"] for f in files]
    return [{"description": f"Update {len(file_list)} files", "subject": f"Update {len(file_list)} files", "body": "", "files": file_list}]


async def analyze_and_generate_commits(
    base_url: str,
    model: str,
    repo_name: str,
    diff_output: str,
    files: list[dict],
) -> list[dict]:
    """Segment diffs into commits; fast path for small, non-conflict changesets."""

    diff_output = diff_output or ""
    use_simple = (
        len(files) <= int(os.getenv("AI_COMMIT_SIMPLE_MAX_FILES", "5"))
        and not _diff_has_merge_conflict_markers(diff_output)
    )

    if use_simple:
        return await _generate_simple_commit(
            base_url, model, repo_name, diff_output, files,
        )
    return await _analyze_and_generate_commits_full(
        base_url, model, repo_name, diff_output, files,
    )


DEEPIRI_PR_TEMPLATE = """## IMPORTANT

- PR must be opened from your personal branch → dev
- You must tag @Team-Deepiri/support-team
- You must update Plaky to "Needs QA"
- Never move a feature/bug to "Done" (Done = production release only)

---

## Description

Briefly explain what this PR does and why.

Include:
- Related Issue number
- Plaky feature name
- Component, feature, or system affected
- Purpose of change (feature, bug fix, improvement, refactor, security, etc.)

---

## Changes

List the most important updates in this PR:

- 
- 
- 

Be specific. Include:
- New or updated functions, services, components, or scripts
- Refactoring or structural improvements
- Dependency or configuration changes
- Any significant implementation details

---

## Related

- Issue:
- Plaky:
- Related PRs (optional):

---

## Testing

Explain how you verified your changes and how to test your feature:

Additional testing details:

---

## Important Notes (Optional)

- Known limitations:
- Blockers:
- CI/CD issues unrelated to this PR:
- Dependencies required for testing:

---

## Workflow Checklist (Required)

- [ ] Branch is up to date with dev
- [ ] PR is from your branch → dev (no longer directly into main)
- [ ] PR title follows convention (feat:, fix:, refactor:, etc.)
- [ ] Plaky feature/bug name included above
- [ ] Tagged @Team-Deepiri/support-team
- [ ] Plaky feature moved to "Needs QA"

---

## Review Requests

@Team-Deepiri/support-team
"""


async def generate_pr_description_ai(base_url: str, model: str, commits: list[dict], prior_commits: list[dict] | None = None) -> tuple[str, str]:
    """Generate PR description using AI with project template"""
    prior_commits = prior_commits or []
    
    commit_log = ""
    if prior_commits:
        commit_log += "## Prior commits on this branch (from earlier pushes):\n"
        for c in prior_commits:
            commit_log += f"- {c['subject']}\n"
            for line in _commit_body_lines(c.get("body")):
                commit_log += f"  {line}\n"
        commit_log += "\n## New commits in this session:\n"
    
    for c in commits:
        commit_log += f"- {c['subject']}\n"
        for line in _commit_body_lines(c.get("body")):
            commit_log += f"  {line}\n"

    system_prompt = """You are filling in a Pull Request description template. You will be given a list of commits.

The commits are divided into two sections:
- Prior commits: commits already on the branch from earlier pushes
- New commits: commits made in this session

From ALL commits produce ONLY the following — nothing else:

1. DESCRIPTION: 1-3 sentences explaining what the PR does and why. Be specific, name actual systems/classes.
   Consider the full context of both prior and new commits.

2. TYPE: Pick exactly ONE type that best describes the dominant change:
   - feat     → new feature or capability added
   - fix      → bug fix or error correction
   - refactor → code restructured without behaviour change
   - docs     → documentation only
   - chore    → build, config, deps, tooling, CI
   - perf     → performance improvement
   - test     → tests added or updated

3. CHANGES: 3-8 bullet points. Each bullet is a concise change pulled directly from the commits.
   Name actual classes, methods, or files. No vague bullets.
   Cover both prior and new commits when relevant.

4. TESTING: 2-4 sentences describing how you would verify this PR (concrete commands, files to touch, or flows).
   Mention the repo or script if relevant (e.g. run a specific test file, manual check of a CLI).

5. TESTING_EXTRA: Optional extra bullets or short notes — edge cases, env vars, Docker/Ollama, or follow-up QA.

Output format — use EXACTLY these markers, no other text:

PR_DESCRIPTION:
<1-3 sentences>

PR_TYPE:
<one of: feat | fix | refactor | docs | chore | perf | test>

PR_CHANGES:
- <change>
- <change>
- <change>

PR_TESTING:
<how to verify / what to run>

PR_TESTING_EXTRA:
- <optional bullet>
- <optional bullet>"""

    user_prompt = f"Commits:\n{commit_log}"

    pr_opts = {
        "num_predict": 1536,
        "temperature": 0.3,
    }
    raw = await send_to_ollama(
        base_url,
        model,
        user_prompt,
        system=system_prompt,
        options=pr_opts,
    )

    description = ""
    pr_type = "feat"
    changes_lines: list[str] = []
    testing_main = ""
    testing_extra = ""
    current = None

    for line in raw.splitlines():
        line = line.strip()
        if line == "PR_DESCRIPTION:":
            current = "desc"
        elif line == "PR_TYPE:":
            current = "type"
        elif line == "PR_CHANGES:":
            current = "changes"
        elif line.startswith("PR_TESTING_EXTRA:") or line.startswith("PR_TESTING_DETAILS:"):
            current = "testing_extra"
            rest = line.split(":", 1)[1].strip() if ":" in line else ""
            if rest:
                testing_extra += rest + "\n"
        elif line.startswith("PR_TESTING:"):
            current = "testing"
            rest = line[len("PR_TESTING:") :].strip()
            if rest:
                testing_main += rest + " "
        elif current == "desc" and line:
            description += line + " "
        elif current == "type" and line:
            clean = re.sub(r"[`*|]", " ", line).lower()
            known = ("feat", "fix", "refactor", "docs", "chore", "perf", "test")
            found = next((t for t in known if re.search(rf"\b{t}\b", clean)), None)
            if found:
                pr_type = found
        elif current == "changes" and line.startswith("-"):
            changes_lines.append(line)
        elif current == "testing" and line:
            testing_main += line + " "
        elif current == "testing_extra" and line:
            testing_extra += line + "\n"

    description = description.strip()
    changes_block = "\n".join(changes_lines) if changes_lines else "- See commits above"
    testing_main = testing_main.strip()
    testing_extra = testing_extra.strip()
    if not testing_main:
        testing_main = (
            "Run the relevant local flow (e.g. the script or service you changed), then smoke-test the happy path. "
            "If tests exist for the touched module, run them with your usual test command."
        )
    if not testing_extra:
        testing_extra = "_None required — add notes here if QA needs a special env, feature flag, or data setup._"

    pr_desc = f"""IMPORTANT:
- PR must be opened from your personal branch → dev
- You must tag @Team-Deepiri/support-team
- You must update Plaky to "Needs QA"
- Never move a task to "Done" (Done = production release only)

---

## Description

{description}

---

## Changes

{changes_block}

---

## Related

- Issue:
- Plaky:
- Related PRs (optional):

---

## Testing

{testing_main}

Additional testing details:

{testing_extra}

---

## Important Notes (Optional)

- Known limitations:
- Blockers:
- CI/CD issues unrelated to this PR:
- Dependencies required for testing:

---

## Workflow Checklist (Required)

- [ ] Branch is up to date with dev
- [ ] PR is from your branch → dev (no longer directly into main)
- [ ] PR title follows convention (feat:, fix:, refactor:, etc.)
- [ ] Plaky feature/bug name included above
- [ ] Tagged @Team-Deepiri/support-team
- [ ] Plaky task moved to "Needs QA"

---

## Review Requests

@Team-Deepiri/support-team"""

    pr_title = f"{pr_type}: {commits[0]['subject'][:80]}" if commits else "Update"
    
    return pr_title, pr_desc


def generate_pr_description(commits: list[dict]) -> str:
    """Generate PR description using Deepiri template with commit summaries"""
    
    commit_log = ""
    for c in commits:
        commit_log += f"- {c.get('subject', 'No description')}\n"
        for line in _commit_body_lines(c.get("body")):
            commit_log += f"  {line}\n"
    
    pr_desc = f"""## Description

<!-- Briefly explain what this PR does and why. Include related Issue number, Plaky feature name, component/feature/system affected, and purpose of change. -->

---

## Changes

{commit_log}

---

## Testing

<!-- Explain how you verified your changes and how to test your feature. -->

---

## Important Notes (Optional)

- Known limitations:
- Blockers:
- Dependencies required for testing:

---

## Workflow Checklist (Required)

- [ ] Branch is up to date with dev
- [ ] PR is from your branch → dev (no longer directly into main)
- [ ] PR title follows convention (feat:, fix:, refactor:, etc.)
- [ ] Plaky feature/bug name included above
- [ ] Tagged @Team-Deepiri/support-team
- [ ] Plaky feature moved to "Needs QA"

---

## Review Requests

@Team-Deepiri/support-team
"""
    return pr_desc


def stage_files(repo_path: str, files: list[str]) -> bool:
    """Stage specific files for commit"""
    try:
        subprocess.run(["git", "add"] + files, cwd=repo_path, check=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"{Colors.RED}Error staging files: {e}{Colors.NC}")
        return False


def commit_changes(repo_path: str, subject: str, body: str) -> bool:
    """Commit staged changes"""
    full_message = subject
    if body:
        full_message += f"\n\n{body}"

    try:
        subprocess.run(
            ["git", "commit", "-m", full_message],
            cwd=repo_path,
            check=True,
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"{Colors.RED}Error committing: {e}{Colors.NC}")
        return False


def set_upstream_if_needed(repo_path: str) -> bool:
    """Set the current branch to track the remote upstream if not already set"""
    try:
        result = subprocess.run(
            ["git", "status", "-b", "--porcelain"],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            return False
        
        branch_line = None
        for line in result.stdout.splitlines():
            if line.startswith("##"):
                branch_line = line
                break
        
        if not branch_line:
            return False
        
        if "..." not in branch_line:
            current_branch = get_current_branch(repo_path)
            if not current_branch:
                return False
            
            upstream_branch = f"origin/{current_branch}"
            try:
                subprocess.run(
                    ["git", "push", "-u", "origin", current_branch],
                    cwd=repo_path,
                    check=True,
                )
                print(f"{Colors.GREEN}✓ Set upstream to {upstream_branch}{Colors.NC}")
                return True
            except subprocess.CalledProcessError as e:
                print(f"{Colors.YELLOW}Warning: Could not set upstream: {e}{Colors.NC}")
                return False
        
        return True
    except Exception as e:
        print(f"{Colors.YELLOW}Warning: Error checking upstream: {e}{Colors.NC}")
        return False


def push_changes(repo_path: str) -> bool:
    """Push changes to remote"""
    try:
        subprocess.run(["git", "push"], cwd=repo_path, check=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"{Colors.RED}Error pushing: {e}{Colors.NC}")
        return False


@lru_cache(maxsize=64)
def get_current_branch(repo_path: str) -> str:
    try:
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            cwd=repo_path, capture_output=True, text=True, check=True,
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return ""


def gh_installed() -> bool:
    try:
        subprocess.run(["gh", "--version"], capture_output=True, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False


def gh_authenticated() -> bool:
    try:
        result = subprocess.run(["gh", "auth", "status"], capture_output=True, text=True)
        return result.returncode == 0
    except FileNotFoundError:
        return False


def install_gh() -> bool:
    """Install GitHub CLI for the current platform"""
    system = subprocess.run(["uname", "-s"], capture_output=True, text=True).stdout.strip().lower()

    print(f"\n{Colors.CYAN}Installing GitHub CLI...{Colors.NC}")

    if system == "darwin":
        try:
            subprocess.run(["brew", "install", "gh"], check=True)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            print(f"{Colors.RED}Homebrew not found. Install gh manually: https://cli.github.com{Colors.NC}")
            return False

    try:
        commands = [
            "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg",
            'echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null',
            "sudo apt-get update -qq",
            "sudo apt-get install -y gh",
        ]
        for cmd in commands:
            result = subprocess.run(cmd, shell=True)
            if result.returncode != 0:
                raise subprocess.CalledProcessError(result.returncode, cmd)
        return True
    except subprocess.CalledProcessError:
        print(f"{Colors.RED}apt install failed. Install gh manually: https://cli.github.com{Colors.NC}")
        return False


def get_existing_pr_for_branch(repo_path: str, branch: str) -> dict | None:
    """Check if there's already an open PR for the given branch"""
    try:
        result = subprocess.run(
            ["gh", "pr", "list", "--head", branch, "--state", "open", "--json", "number,title,url,body"],
            cwd=repo_path, capture_output=True, text=True,
        )
        if result.returncode == 0 and result.stdout.strip():
            prs = json.loads(result.stdout)
            if prs:
                return prs[0]
    except (subprocess.CalledProcessError, json.JSONDecodeError, FileNotFoundError):
        pass
    return None


def comment_on_pr(repo_path: str, pr_number: int, comment: str) -> bool:
    """Add a comment to an existing PR"""
    try:
        result = subprocess.run(
            ["gh", "pr", "comment", str(pr_number), "--body", comment],
            cwd=repo_path, capture_output=True, text=True,
        )
        return result.returncode == 0
    except FileNotFoundError:
        return False


def get_prior_commits(repo_path: str, default_branch: str, new_commit_count: int = 0) -> list[dict]:
    """Get commits on the current branch prior to the ones being committed"""
    try:
        merge_base = subprocess.run(
            ["git", "merge-base", f"origin/{default_branch}", "HEAD"],
            cwd=repo_path, capture_output=True, text=True,
        )
        if merge_base.returncode != 0:
            return []
        
        merge_base_sha = merge_base.stdout.strip()
        if not merge_base_sha:
            return []
        
        result = subprocess.run(
            ["git", "log", f"{merge_base_sha}..HEAD", "--format=%H|%s|%b", "--reverse"],
            cwd=repo_path, capture_output=True, text=True,
        )
        if result.returncode != 0:
            return []
        
        commits = []
        for line in result.stdout.strip().split("\n"):
            if not line.strip():
                continue
            parts = line.split("|", 2)
            sha = parts[0]
            subject = parts[1] if len(parts) > 1 else ""
            body = parts[2] if len(parts) > 2 else ""
            commits.append({"sha": sha[:8], "subject": subject, "body": body})
        
        if new_commit_count > 0 and len(commits) > new_commit_count:
            return commits[:-new_commit_count]
        elif new_commit_count >= len(commits):
            return []
        
        return commits
    except Exception:
        return []


@lru_cache(maxsize=64)
def get_default_branch(repo_path: str) -> str:
    """Detect the repo's default branch (main/master/etc)"""
    try:
        result = subprocess.run(
            ["git", "symbolic-ref", "refs/remotes/origin/HEAD"],
            cwd=repo_path, capture_output=True, text=True,
        )
        if result.returncode == 0:
            return result.stdout.strip().split("/")[-1]
    except Exception:
        pass
    for branch in ("main", "master", "develop"):
        r = subprocess.run(
            ["git", "show-ref", "--verify", f"refs/remotes/origin/{branch}"],
            cwd=repo_path, capture_output=True,
        )
        if r.returncode == 0:
            return branch
    return "main"


async def ensure_gh_ready() -> bool:
    """Ensure gh is installed and authenticated"""
    if not gh_installed():
        print(f"\n{Colors.YELLOW}GitHub CLI (gh) is not installed.{Colors.NC}")
        print(f"{Colors.BLUE}Install it now? [y/N]: {Colors.NC}", end="")
        if input().strip().lower() != "y":
            return False
        if not install_gh():
            return False
        print(f"{Colors.GREEN}✓ gh installed{Colors.NC}")

    if not gh_authenticated():
        print(f"\n{Colors.YELLOW}gh is not authenticated with GitHub.{Colors.NC}")
        print(f"{Colors.BLUE}Run gh auth login now? [y/N]: {Colors.NC}", end="")
        if input().strip().lower() != "y":
            return False
        print(f"{Colors.CYAN}Launching gh auth login...{Colors.NC}")
        result = subprocess.run(["gh", "auth", "login"])
        if result.returncode != 0 or not gh_authenticated():
            print(f"{Colors.RED}Authentication failed.{Colors.NC}")
            return False
        print(f"{Colors.GREEN}✓ Authenticated{Colors.NC}")

    return True


async def get_ollama_models(base_url: str) -> list:
    """Get list of available models from Ollama"""
    try:
        client = _get_http_client()
        response = await client.get(f"{base_url}/api/tags")
        response.raise_for_status()
        data = response.json()
        return [m["name"] for m in data.get("models", [])]
    except Exception:
        return []


def get_last_used_model(base_url: str) -> str | None:
    """Best-effort: infer last-used model from local Ollama logs."""
    try:
        ollama_dir = os.path.expanduser("~/.ollama")
        if os.path.exists(ollama_dir):
            logs_dir = os.path.join(ollama_dir, "logs")
            if os.path.exists(logs_dir):
                for f in os.listdir(logs_dir):
                    if f.endswith(".log"):
                        log_path = os.path.join(logs_dir, f)
                        try:
                            with open(log_path, "r", errors="ignore") as fp:
                                content = fp.read()
                                lines = content.split("\n")
                                for line in reversed(lines):
                                    if "pull model" in line.lower():
                                        for model in ["qwen", "gemma", "llama", "mistral", "codellama", "phi"]:
                                            if model in line.lower():
                                                return line.lower().split(model)[0].split()[-1] + model
                                    if "using model" in line.lower():
                                        for model in ["qwen", "gemma", "llama", "mistral", "codellama", "phi"]:
                                            if model in line.lower():
                                                idx = line.lower().find(model)
                                                return line.lower()[idx:].split()[0]
                        except Exception:
                            pass
    except Exception:
        pass
    return None


def get_system_resources() -> dict:
    """Get system RAM and GPU VRAM info (Linux/WSL)."""
    resources: dict = {"ram_gb": 0.0, "vram_gb": 0.0}

    try:
        result = subprocess.run(["free", "-b"], capture_output=True, text=True)
        if result.returncode == 0:
            lines = result.stdout.strip().split("\n")
            if len(lines) > 1:
                parts = lines[1].split()
                if len(parts) > 1:
                    resources["ram_gb"] = int(parts[1]) / (1024**3)
    except Exception as e:
        # Best-effort RAM detection failed; keep default value of 0.0.
        print(f"[ai-commit] Warning: failed to detect system RAM: {e}", file=sys.stderr)

    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=memory.total", "--format=csv,noheader,nounits"],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0 and result.stdout.strip():
            vram_mb = int(result.stdout.strip().split("\n")[0])
            resources["vram_gb"] = vram_mb / 1024
    except Exception as e:
        # Best-effort VRAM detection failed; keep default value of 0.0.
        print(f"[ai-commit] Warning: failed to detect GPU VRAM: {e}", file=sys.stderr)

    return resources


MODEL_REQUIREMENTS = {
    "qwen2.5:14b": {"ram": 16, "vram": 10},
    "qwen2.5:7b": {"ram": 8, "vram": 6},
    "gemma2:9b": {"ram": 10, "vram": 7},
    "gemma2:2b": {"ram": 4, "vram": 2},
    "llama3.1:8b": {"ram": 8, "vram": 6},
    "llama3.1:70b": {"ram": 64, "vram": 40},
    "mistral:7b": {"ram": 8, "vram": 6},
    "codellama:7b": {"ram": 8, "vram": 6},
    "phi3:14b": {"ram": 14, "vram": 10},
    "phi3:3.8b": {"ram": 4, "vram": 3},
}


def select_best_model(models: list[str], resources: dict) -> str:
    """Pick a reasonable default model from available VRAM/RAM."""
    ram = resources.get("ram_gb", 0)
    vram = resources.get("vram_gb", 0)

    candidates: list[tuple[str, float]] = []
    for m in models:
        model_name = m.split(":")[0].lower() if ":" in m else m.lower()

        for req_name, reqs in MODEL_REQUIREMENTS.items():
            if model_name in req_name:
                if vram >= reqs["vram"] or ram >= reqs["ram"]:
                    score = vram * 2 + ram
                    candidates.append((m, score))
                break
        else:
            candidates.append((m, 0.0))

    if candidates:
        candidates.sort(key=lambda x: x[1], reverse=True)
        return candidates[0][0]

    return models[0] if models else ""


def auto_select_model(base_url: str, models: list[str]) -> str:
    """Auto-select model: try last used from logs, then best fit for hardware."""
    if not models:
        return ""

    if len(models) == 1:
        return models[0]

    last_used = get_last_used_model(base_url)
    if last_used:
        for m in models:
            if last_used in m.lower():
                return m

    resources = get_system_resources()
    return select_best_model(models, resources)


def confirm_commit(repo_name: str, subject: str, body: str, files: list[str], commit_num: int, total: int) -> bool:
    """Ask user to confirm the commit"""
    print(f"\n{Colors.CYAN}╔{'═'*58}╗{Colors.NC}")
    print(f"{Colors.CYAN}║ Repository: {repo_name:<43}║{Colors.NC}")
    print(f"{Colors.CYAN}║ Commit {commit_num}/{total}:{' '*44}║{Colors.NC}")
    print(f"{Colors.CYAN}╚{'═'*58}╝{Colors.NC}")
    print(f"\n{Colors.CYAN}--- Subject ---{Colors.NC}")
    print(f"{Colors.GREEN}{subject}{Colors.NC}")
    if body:
        print(f"\n{Colors.CYAN}--- Body ---{Colors.NC}")
        print(f"{Colors.YELLOW}{body}{Colors.NC}")
    print(f"\n{Colors.CYAN}--- Files ({len(files)}) ---{Colors.NC}")
    for f in files[:10]:
        print(f"  {Colors.YELLOW}{f}{Colors.NC}")
    if len(files) > 10:
        print(f"  {Colors.YELLOW}... and {len(files) - 10} more{Colors.NC}")
    print()

    response = input(f"{Colors.BLUE}[y] Commit  [s] Skip  [q] Quit  [a] Commit all remaining: {Colors.NC}").strip().lower()
    
    if response == "q":
        print(f"\n{Colors.YELLOW}Quitting...{Colors.NC}")
        sys.exit(0)
    elif response == "s":
        return False
    elif response == "a":
        return "commit_all"
    
    return response == "y"


def extract_diff_for_files(diff_output: str, files: list[str], untracked_diffs: dict | None = None, submodule_pointers: dict | None = None) -> str:
    """Extract diff sections relevant to the given files"""
    sections = []
    current_section = []
    current_file = None
    file_set = set(files)

    for line in diff_output.split("\n"):
        if line.startswith("diff --git"):
            if current_file and current_file in file_set and current_section:
                sections.append("\n".join(current_section))
            match = re.search(r"b/(.+)", line)
            current_file = match.group(1) if match else None
            current_section = [line]
        else:
            current_section.append(line)

    if current_file and current_file in file_set and current_section:
        sections.append("\n".join(current_section))

    if untracked_diffs:
        for f in files:
            if f in untracked_diffs:
                sections.append(untracked_diffs[f])

    if submodule_pointers:
        for f in files:
            if f in submodule_pointers:
                info = submodule_pointers[f]
                sections.append(
                    f"diff --git a/{f} b/{f}\n"
                    f"--- a/{f}\n+++ b/{f}\n"
                    f"-Subproject commit {info['old_sha']}\n"
                    f"+Subproject commit {info['new_sha']}"
                )

    return "\n".join(sections)


def has_changes(repo_path: str) -> bool:
    """Check if a repo has any changes (staged, unstaged, or untracked)"""
    try:
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        return bool(result.stdout.strip())
    except Exception:
        return False


def get_repos_with_changes(repos: list[dict]) -> tuple[list[dict], list[dict], dict]:
    """
    Separate repos into: dirty_submodules, clean_repos, main_repo
    Checks all repos for changes in parallel.
    """
    if not repos:
        return [], [], None, {}

    with ThreadPoolExecutor(max_workers=min(8, len(repos))) as pool:
        flags = list(pool.map(lambda r: has_changes(r["path"]), repos))

    dirty_submodules = []
    clean_repos = []
    main_repo = None
    dirty_submodule_paths = {}

    for repo, dirty in zip(repos, flags):
        is_submodule = repo.get("is_submodule", False)
        if dirty:
            if is_submodule:
                dirty_submodules.append(repo)
                dirty_submodule_paths[repo["name"]] = repo["path"]
            else:
                main_repo = repo
        else:
            if is_submodule:
                clean_repos.append(repo)
            else:
                main_repo = repo

    return dirty_submodules, clean_repos, main_repo, dirty_submodule_paths


def show_status(submodules: list[dict], main_repo: dict | None, repo_root: str):
    print("\n" + "="*50)
    print(f"{Colors.CYAN}Status of all repositories{Colors.NC}")
    print("="*50 + "\n")

    for sub in submodules:
        full_path = sub["path"]
        print(f"[submodule] {sub['name']}:")

        if not os.path.isdir(full_path):
            print(f"   {Colors.YELLOW}Directory not found{Colors.NC}")
            print("")
            continue

        try:
            result = subprocess.run(
                ["git", "status", "--short"],
                cwd=full_path,
                capture_output=True,
                text=True,
            )
            branch = get_current_branch(full_path) or "(detached HEAD)"
            print(f"   Branch: {branch}")
            
            if result.stdout.strip():
                print(f"   {Colors.YELLOW}Status: Has changes{Colors.NC}")
                for line in result.stdout.strip().split("\n"):
                    print(f"      {line}")
            else:
                print(f"   {Colors.GREEN}Status: Working tree clean{Colors.NC}")
        except Exception as e:
            print(f"   {Colors.RED}Error: {e}{Colors.NC}")
        print("")

    if main_repo:
        print(f"[main] {main_repo['name']}:")
        try:
            branch = get_current_branch(main_repo["path"]) or "(detached HEAD)"
            print(f"   Branch: {branch}")
            
            result = subprocess.run(
                ["git", "status", "--short"],
                cwd=main_repo["path"],
                capture_output=True,
                text=True,
            )
            
            if result.stdout.strip():
                print(f"   {Colors.YELLOW}Status: Has changes{Colors.NC}")
                for line in result.stdout.strip().split("\n"):
                    print(f"      {line}")
            else:
                print(f"   {Colors.GREEN}Status: Working tree clean{Colors.NC}")
        except Exception as e:
            print(f"   {Colors.RED}Error: {e}{Colors.NC}")
    print("")


async def handle_no_changes_pr_flow(repos: list[dict], ollama_url: str, model: str) -> None:
    """When nothing was committed this session, check if the branch has prior commits and offer PR management."""
    gh_ready: bool | None = None

    for repo in repos:
        repo_path = repo["path"]
        repo_name = repo["name"]

        current_branch = get_current_branch(repo_path)
        if not current_branch:
            continue
        base_branch = get_default_branch(repo_path)
        if current_branch == base_branch:
            continue

        branch_commits = get_prior_commits(repo_path, base_branch, 0)
        if not branch_commits:
            continue

        print(f"\n{Colors.CYAN}── {repo_name}: {len(branch_commits)} unpushed/open commit(s) on {current_branch} ──{Colors.NC}")
        for c in branch_commits[-5:]:
            print(f"  {Colors.YELLOW}·{Colors.NC} {c['subject']}")
        if len(branch_commits) > 5:
            print(f"  {Colors.YELLOW}  ... and {len(branch_commits) - 5} more{Colors.NC}")

        print(f"\n{Colors.BLUE}[p] Manage PR  [s] Skip: {Colors.NC}", end="")
        if input().strip().lower() != "p":
            continue

        existing_pr = get_existing_pr_for_branch(repo_path, current_branch)

        if existing_pr:
            print(f"  {Colors.YELLOW}Existing PR #{existing_pr['number']}: {existing_pr['title']}{Colors.NC}")
            print(f"  {Colors.CYAN}{existing_pr['url']}{Colors.NC}")
            print(f"\n{Colors.BLUE}[c] Add comment  [s] Skip: {Colors.NC}", end="")
            if input().strip().lower() == "c":
                commit_list = "\n".join(f"- {c['subject']}" for c in branch_commits)
                comment = f"## Commits on this branch\n\n{commit_list}\n\n---\n*ai-commit.py*"
                if comment_on_pr(repo_path, existing_pr["number"], comment):
                    print(f"  {Colors.GREEN}✓ Comment added to PR #{existing_pr['number']}{Colors.NC}")
                else:
                    print(f"  {Colors.RED}✗ Failed to comment{Colors.NC}")
        else:
            if gh_ready is None:
                gh_ready = await ensure_gh_ready()
            if not gh_ready:
                continue

            async with Spinner(f"Generating PR description for {repo_name}..."):
                pr_title, pr_desc = await generate_pr_description_ai(ollama_url, model, branch_commits)

            print(f"\n{Colors.CYAN}{'─'*60}{Colors.NC}")
            print(f"Title: {pr_title}")
            print(pr_desc)
            print(f"{Colors.CYAN}{'─'*60}{Colors.NC}")
            print(f"\n{Colors.BLUE}Create PR? [y/N]: {Colors.NC}", end="")
            if input().strip().lower() == "y":
                try:
                    result = subprocess.run(
                        ["gh", "pr", "create",
                         "--title", pr_title,
                         "--body", pr_desc,
                         "--base", base_branch,
                         "--head", current_branch],
                        cwd=repo_path, capture_output=True, text=True,
                    )
                    if result.returncode == 0:
                        print(f"  {Colors.GREEN}✓ PR created: {result.stdout.strip()}{Colors.NC}")
                    else:
                        print(f"  {Colors.RED}✗ Failed: {result.stderr.strip()}{Colors.NC}")
                except FileNotFoundError:
                    print(f"{Colors.RED}gh not found{Colors.NC}")


async def main():
    auto_commit = "-y" in sys.argv or "--yes" in sys.argv
    full_auto = "--full-auto" in sys.argv or "--full" in sys.argv
    ollama_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
    root_path = find_script_git_root()

    print(f"{Colors.CYAN}╔{'═'*56}╗{Colors.NC}")
    print(f"{Colors.CYAN}║{' AI Git Commit (Deepiri) ':^56}║{Colors.NC}")
    print(f"{Colors.CYAN}╚{'═'*56}╝{Colors.NC}\n")

    print(f"{Colors.CYAN}Finding git repositories...{Colors.NC}")
    repos = find_git_repos(root_path)
    repos_with_changes = {r["path"]: True for r in repos if has_changes(r["path"])}

    if not repos:
        print(f"{Colors.RED}No git repositories found.{Colors.NC}")
        sys.exit(1)

    repos_with_changes_count = sum(1 for r in repos if r["path"] in repos_with_changes)
    print(f"\n{Colors.GREEN}Found {len(repos)} repository(ies) ({repos_with_changes_count} with changes):{Colors.NC}")
    for i, repo in enumerate(repos):
        markers = []
        if repo.get("is_submodule"):
            markers.append("submodule")
        if repo.get("is_sibling"):
            markers.append("sibling")
        marker_str = f" ({', '.join(markers)})" if markers else ""
        has_change = repo["path"] in repos_with_changes
        status = f" {Colors.YELLOW}●{Colors.NC}" if has_change else f" {Colors.GREEN}○{Colors.NC}"
        print(f"  {i + 1}) {repo['name']}{marker_str}{status}")
    print(f"  {len(repos) + 1}) (all)")
    print(f"  status) Show status of all repos")

    if full_auto:
        selected_repos = list(repos)
        selected_repos.sort(key=lambda r: 0 if r.get("is_submodule") else 1)
        print(f"\n{Colors.YELLOW}[FULL-AUTO]{Colors.NC} All {len(selected_repos)} repos (submodules first); no prompts for commit/push/PR.")
    else:
        print(f"\n{Colors.CYAN}Select repositories to process (comma-separated, number for all):{Colors.NC}", end="")
        selection = input().strip().lower()

        if selection == "status":
            submodules = [r for r in repos if r.get("is_submodule")]
            main_repo = [r for r in repos if not r.get("is_submodule")]
            main = main_repo[0] if main_repo else None
            show_status(submodules, main, root_path)
            sys.exit(0)

        selected_repos = []
        if selection == "all" or selection == str(len(repos) + 1) or selection == "a":
            repos_with_changes_list = [r for r in repos if r["path"] in repos_with_changes]

            if not repos_with_changes_list:
                print(f"\n{Colors.GREEN}No repositories have changes to commit.{Colors.NC}")
                sys.exit(0)

            print(f"\n{Colors.CYAN}Processing {len(repos_with_changes_list)} repo(s) with changes:{Colors.NC}")
            selected_repos = repos_with_changes_list
        else:
            try:
                indices = [int(x.strip()) - 1 for x in selection.split(",") if x.strip().isdigit()]
                selected_repos = [repos[i] for i in indices if 0 <= i < len(repos)]
            except ValueError:
                print(f"{Colors.RED}Invalid selection.{Colors.NC}")
                sys.exit(1)

    if not selected_repos:
        print(f"{Colors.RED}No repositories selected.{Colors.NC}")
        sys.exit(1)

    if len(selected_repos) > 1:
        with ThreadPoolExecutor(max_workers=min(8, len(selected_repos))) as pool:
            dirty_flags = list(pool.map(lambda r: has_changes(r["path"]), selected_repos))
        active_repos = [r for r, dirty in zip(selected_repos, dirty_flags) if dirty]
        skipped_clean = len(selected_repos) - len(active_repos)
        if skipped_clean:
            print(f"  {Colors.YELLOW}{skipped_clean} repo(s) have no changes — skipping{Colors.NC}")
    else:
        active_repos = selected_repos

    if not active_repos:
        print(f"{Colors.RED}No repositories with changes to process.{Colors.NC}")
        sys.exit(0)

    status = check()
    if not status["ok"]:
        print(f"\n{Colors.YELLOW}Ollama is not running.{Colors.NC}")
        print(f"{Colors.CYAN}[s] Start automatically  [m] Pull models  [q] Quit: {Colors.NC}", end="")
        response = input().strip().lower()
        if response == "s":
            if not start_ollama(root_path, ollama_url):
                print(f"{Colors.RED}Could not start Ollama. Please start it manually.{Colors.NC}")
                sys.exit(1)
        elif response == "m":
            check_script = find_check_ollama_script(root_path)
            if check_script:
                print(f"\n{Colors.CYAN}Running check-ollama-models.sh...{Colors.NC}")
                subprocess.run([check_script], cwd=root_path)
            else:
                print(f"{Colors.YELLOW}check-ollama-models.sh not found. Please install models manually.{Colors.NC}")
            sys.exit(0)
        elif response != "":
            sys.exit(0)

    async with Spinner(f"Connecting to Ollama at {ollama_url}..."):
        models = await get_ollama_models(ollama_url)
    if models:
        print(f"  {Colors.GREEN}✔{Colors.NC} Ollama connected")

    if not models:
        print(f"{Colors.YELLOW}No models found in Ollama.{Colors.NC}")
        print(f"{Colors.RED}No models available.{Colors.NC}")
        sys.exit(1)

    if len(models) == 1:
        model = models[0]
        print(f"{Colors.GREEN}Using model: {model}{Colors.NC}\n")
    elif full_auto:
        model = auto_select_model(ollama_url, models)
        resources = get_system_resources()
        print(f"{Colors.GREEN}Auto-selected model: {model}{Colors.NC}")
        print(f"  System RAM: {resources.get('ram_gb', 0):.1f}GB, GPU VRAM: {resources.get('vram_gb', 0):.1f}GB\n")
    else:
        print(f"\n{Colors.GREEN}Available models:{Colors.NC}")
        for i, m in enumerate(models):
            print(f"  {i + 1}) {m}")
        print(f"\n{Colors.CYAN}Select model [1]: {Colors.NC}", end="")
        model_input = input().strip()

        if not model_input:
            model = models[0]
        elif model_input.isdigit() and 1 <= int(model_input) <= len(models):
            model = models[int(model_input) - 1]
        else:
            print(f"{Colors.RED}Invalid selection, using first model.{Colors.NC}")
            model = models[0]

        print(f"{Colors.GREEN}Using model: {model}{Colors.NC}\n")

    commit_all_remaining = False
    total_commits = 0
    skipped_commits = 0
    all_commits_made = []

    for repo in active_repos:
        repo_path = repo["path"]
        repo_name = repo["name"]

        print(f"\n{Colors.MAGENTA}{'='*60}{Colors.NC}")
        print(f"{Colors.MAGENTA}Repository: {repo_name}{Colors.NC}")
        print(f"{Colors.MAGENTA}{'='*60}{Colors.NC}")

        diff_output = get_git_diff(repo_path)
        untracked = get_untracked_files(repo_path)

        if not diff_output and not untracked:
            print(f"{Colors.YELLOW}No changes in {repo_name}.{Colors.NC}")
            continue

        files = parse_changed_files(diff_output)

        submodule_pointers = {}
        for f in files:
            if f.get("is_submodule_pointer"):
                submodule_pointers[f["file"]] = {"old_sha": f["old_sha"], "new_sha": f["new_sha"]}

        known_submodule_paths = parse_gitmodules(repo_path)
        dirty_subs = get_dirty_submodules(repo_path, known_submodule_paths)
        for sub in dirty_subs:
            print(f"  {Colors.YELLOW}⚠{Colors.NC}  {sub['path']} has uncommitted changes "
                  f"({sub['modified']} modified, {sub['untracked']} untracked) — commit inside the submodule first")

        untracked_diffs = {}
        for upath in untracked:
            files.append({"file": upath, "hunks": [], "untracked": True})
            untracked_diffs[upath] = get_new_file_diff(repo_path, upath)

        if not files:
            print(f"{Colors.YELLOW}No files changed in {repo_name}.{Colors.NC}")
            continue

        total_files = len(files)
        print(f"  {Colors.CYAN}●{Colors.NC} {total_files} file(s) to commit\n")

        async with Spinner(f"Analysing {total_files} file(s)...") as spinner:
            commit_plan = await analyze_and_generate_commits(
                base_url=ollama_url,
                model=model,
                repo_name=repo_name,
                diff_output=diff_output,
                files=files,
            )
        print(f"  {Colors.GREEN}✔{Colors.NC} Segmented into {len(commit_plan)} commit(s) with messages\n")

        generated = [
            (commit, commit.get("subject") or commit.get("description", "Update"), commit.get("body", ""))
            for commit in commit_plan
        ]

        print(f"{Colors.BOLD}{Colors.GREEN}Segmented into {len(generated)} commit(s):{Colors.NC}")
        for i, (commit, subject, _) in enumerate(generated):
            label = subject or commit.get("description", "No description")
            print(f"  {i + 1}) {label[:60]}")
            print(f"     Files: {', '.join(commit.get('files', [])[:5])}{'...' if len(commit.get('files', [])) > 5 else ''}")

        repo_auto_commit = auto_commit or full_auto

        if not repo_auto_commit:
            print(f"\n{Colors.BLUE}[a] Auto-commit all  [r] Review each  [q] Quit: {Colors.NC}", end="")
            mode = input().strip().lower()
            if mode == "q":
                print(f"{Colors.YELLOW}Quitting...{Colors.NC}")
                sys.exit(0)
            repo_auto_commit = mode == "a"

        if full_auto:
            print(f"\n{Colors.YELLOW}[FULL-AUTO MODE]{Colors.NC}")
            print(f"  - Auto-committing all changes")
            print(f"  - Auto-pushing to remote")
            print(f"  - Auto-generating PR description")
            print(f"  - Auto-creating/commenting PRs (skipping confirmations)\n")

        print(f"\n{Colors.CYAN}Starting commits...{Colors.NC}")

        for i, (commit, subject, body) in enumerate(generated):
            files_to_commit = commit.get("files", [])

            if not files_to_commit:
                print(f"{Colors.YELLOW}Skipping commit {i+1} - no files{Colors.NC}")
                skipped_commits += 1
                continue

            if repo_auto_commit or commit_all_remaining:
                confirmed = True
            else:
                confirmed = confirm_commit(repo_name, subject, body, files_to_commit, i + 1, len(generated))
                if confirmed == "commit_all":
                    commit_all_remaining = True
                    confirmed = True

            if confirmed:
                set_upstream_if_needed(repo_path)
                
                staged = stage_files(repo_path, files_to_commit)
                
                if staged:
                    committed = commit_changes(repo_path, subject, body)
                    
                    if committed:
                        print(f"{Colors.GREEN}✓ Committed: {subject[:50]}{Colors.NC}")
                        total_commits += 1
                        all_commits_made.append({
                            "repo": repo_name,
                            "repo_path": repo_path,
                            "subject": subject,
                            "body": body,
                            "files": files_to_commit,
                        })
                    else:
                        print(f"{Colors.RED}✗ Failed to commit{Colors.NC}")
                else:
                    print(f"{Colors.RED}✗ Failed to stage files{Colors.NC}")
            else:
                print(f"{Colors.YELLOW}⊘ Skipped commit {i+1}{Colors.NC}")
                skipped_commits += 1

    print(f"\n{Colors.CYAN}{'='*60}{Colors.NC}")
    print(f"{Colors.GREEN}Done!{Colors.NC}")
    print(f"  Commits created: {Colors.GREEN}{total_commits}{Colors.NC}")
    if skipped_commits > 0:
        print(f"  Skipped: {Colors.YELLOW}{skipped_commits}{Colors.NC}")
    print(f"{Colors.CYAN}{'='*60}{Colors.NC}")

    if total_commits == 0:
        await handle_no_changes_pr_flow(active_repos, ollama_url, model)
        return

    if total_commits > 0 and all_commits_made:
        repos_pushed = {}

        if full_auto:
            print(f"\n{Colors.CYAN}Pushing to remote (full-auto)...{Colors.NC}")
            do_push = True
        else:
            print(f"\n{Colors.BLUE}Push to remote? [y/N]: {Colors.NC}", end="")
            do_push = input().strip().lower() == "y"
        if do_push:
            repos_to_push = {}
            for repo_info in all_commits_made:
                repo_name = repo_info["repo"]
                if repo_name not in repos_to_push:
                    repos_to_push[repo_name] = repo_info.get("repo_path", root_path)

            for repo_name, repo_path in repos_to_push.items():
                print(f"\n{Colors.CYAN}Pushing {repo_name}...{Colors.NC}")
                if push_changes(repo_path):
                    print(f"{Colors.GREEN}✓ Pushed{Colors.NC}")
                    repos_pushed[repo_name] = True
                else:
                    print(f"{Colors.RED}✗ Push failed{Colors.NC}")

        if full_auto:
            do_pr = True
        else:
            print(f"\n{Colors.BLUE}Generate PR description? [y/N]: {Colors.NC}", end="")
            do_pr = input().strip().lower() == "y"
        if do_pr:
            print(f"")

            repos_commits: dict[str, list] = {}
            for repo_info in all_commits_made:
                repo_name = repo_info["repo"]
                if repo_name not in repos_commits:
                    repos_commits[repo_name] = []
                repos_commits[repo_name].append(repo_info)

            gh_ready: bool | None = None

            for repo_name, commits in repos_commits.items():
                repo_path = commits[0].get("repo_path", root_path)
                
                base_branch = get_default_branch(repo_path)
                prior_commits = get_prior_commits(repo_path, base_branch, len(commits))
                
                async with Spinner(f"Generating PR description for {repo_name}..."):
                    pr_title, pr_desc = await generate_pr_description_ai(ollama_url, model, commits, prior_commits)
                
                print(f"\n{Colors.CYAN}{'─'*60}{Colors.NC}")
                print(f"{Colors.BOLD}PR — {repo_name}{Colors.NC}")
                print(f"{Colors.CYAN}{'─'*60}{Colors.NC}\n")
                print(f"Title: {pr_title}\n")
                print(pr_desc)
                print(f"\n{Colors.CYAN}{'─'*60}{Colors.NC}")

                if not repos_pushed.get(repo_name):
                    print(f"\n{Colors.YELLOW}  [WARN] {repo_name} was not pushed — skipping PR creation.{Colors.NC}")
                    continue

                current_branch = get_current_branch(repo_path)
                if current_branch == base_branch:
                    print(f"\n{Colors.YELLOW}WARNING: You are currently on the '{base_branch}' branch.{Colors.NC}")
                    print(f"{Colors.YELLOW}You must switch to a feature branch before creating a PR.{Colors.NC}")
                    if full_auto:
                        print(f"{Colors.YELLOW}Skipping PR (full-auto cannot run interactive branch setup on {base_branch}).{Colors.NC}")
                        continue

                if full_auto:
                    print(f"\n{Colors.CYAN}Auto-creating PR for {repo_name}...{Colors.NC}")
                    want_pr = True
                else:
                    print(f"\n{Colors.BLUE}Create PR on GitHub? [y/N]: {Colors.NC}", end="")
                    want_pr = input().strip().lower() == "y"

                if not want_pr:
                    continue

                if gh_ready is None:
                    gh_ready = await ensure_gh_ready()
                if not gh_ready:
                    if not full_auto:
                        pr_output_dir = os.path.join(root_path, ".git", "ai-commit-output")
                        os.makedirs(pr_output_dir, exist_ok=True)
                        pr_file = os.path.join(pr_output_dir, f"pr-description-{repo_name}.md")
                        with open(pr_file, "w") as f:
                            f.write(f"# {pr_title}\n\n{pr_desc}")
                        print(f"\n{Colors.GREEN}✓ PR description saved to: {pr_file}{Colors.NC}")
                    else:
                        print(f"{Colors.YELLOW}Skipping PR creation (gh not available).{Colors.NC}")
                    continue

                if gh_ready:
                    if current_branch and current_branch != base_branch:
                        existing_pr = get_existing_pr_for_branch(repo_path, current_branch)
                        pr_action = None
                        if existing_pr:
                            print(f"  {Colors.YELLOW}Found existing PR: #{existing_pr['number']} — {existing_pr['title']}{Colors.NC}")
                            print(f"  {Colors.CYAN}URL:{Colors.NC} {existing_pr['url']}")
                            if full_auto:
                                commit_list = "\n".join([f"- {c['subject']}" for c in commits])
                                comment = f"""## New commits pushed

{commit_list}

---
*Auto-generated comment from ai-commit.py*"""
                                if comment_on_pr(repo_path, existing_pr["number"], comment):
                                    print(f"  {Colors.GREEN}✓ Comment added to PR #{existing_pr['number']}{Colors.NC}")
                                else:
                                    print(f"  {Colors.RED}✗ Failed to comment{Colors.NC}")
                                continue
                            print(f"\n{Colors.BLUE}[c] Comment on existing PR  [n] Create new PR  [s] Skip: {Colors.NC}", end="")
                            pr_action = input().strip().lower()
                            if pr_action == "c":
                                commit_list = "\n".join([f"- {c['subject']}" for c in commits])
                                comment = f"## New commits pushed\n\n{commit_list}\n\n---\n*Auto-generated by ai-commit.py*"
                                if comment_on_pr(repo_path, existing_pr["number"], comment):
                                    print(f"  {Colors.GREEN}✓ Comment added to PR #{existing_pr['number']}{Colors.NC}")
                                else:
                                    print(f"  {Colors.RED}✗ Failed to comment{Colors.NC}")
                            elif pr_action != "n":
                                print(f"{Colors.YELLOW}Skipped.{Colors.NC}")
                                continue
                        if not existing_pr or pr_action == "n":
                            try:
                                result = subprocess.run(
                                    ["gh", "pr", "create",
                                     "--title", pr_title,
                                     "--body", pr_desc,
                                     "--base", base_branch,
                                     "--head", current_branch],
                                    cwd=repo_path,
                                    capture_output=True,
                                    text=True,
                                )
                                if result.returncode == 0:
                                    print(f"  {Colors.GREEN}✓ PR created: {result.stdout.strip()}{Colors.NC}")
                                else:
                                    print(f"  {Colors.RED}✗ Failed: {result.stderr.strip()}{Colors.NC}")
                            except FileNotFoundError:
                                print(f"{Colors.RED}gh not found{Colors.NC}")
                    else:
                        print(f"{Colors.YELLOW}Currently on {base_branch} — need to switch to a feature branch.{Colors.NC}")
                        print(f"\n{Colors.CYAN}Available remote branches:{Colors.NC}")
                        try:
                            result = subprocess.run(
                                ["git", "branch", "-r"],
                                cwd=repo_path,
                                capture_output=True,
                                text=True,
                            )
                            remote_branches = []
                            for line in result.stdout.strip().split("\n"):
                                line = line.strip()
                                if line and "HEAD" not in line and not line.startswith("origin/HEAD"):
                                    remote_branches.append(line)

                            page_size = 20
                            offset = 0
                            while True:
                                display_branches = remote_branches[offset:offset + page_size]
                                for i, b in enumerate(display_branches):
                                    print(f"  {offset + i + 1}) {b}")

                                remaining = len(remote_branches) - offset - page_size
                                if remaining > 0:
                                    print(f"  ... and {remaining} more")

                                print(f"\n{Colors.CYAN}Enter branch number, name, 'more' for more, 'new' to create, or 'n' to skip: {Colors.NC}", end="")
                                branch_choice = input().strip()

                                if branch_choice.lower() == "more":
                                    offset += page_size
                                    if offset >= len(remote_branches):
                                        offset = 0
                                    continue
                                break

                            if branch_choice.lower() == "n" or not branch_choice:
                                print(f"{Colors.YELLOW}Skipping PR creation.{Colors.NC}")
                            elif branch_choice.lower() == "new":
                                print(f"{Colors.CYAN}Enter new branch name: {Colors.NC}", end="")
                                new_branch = input().strip()
                                if new_branch:
                                    print(f"\n{Colors.CYAN}Creating new branch {new_branch} from current HEAD...{Colors.NC}")
                                    checkout_result = subprocess.run(
                                        ["git", "checkout", "-b", new_branch],
                                        cwd=repo_path,
                                        capture_output=True,
                                        text=True,
                                    )
                                    if checkout_result.returncode == 0:
                                        print(f"{Colors.GREEN}✓ Created branch {new_branch}{Colors.NC}")
                                        print(f"{Colors.CYAN}Pushing to remote...{Colors.NC}")
                                        push_result = subprocess.run(
                                            ["git", "push", "-u", "origin", new_branch],
                                            cwd=repo_path,
                                            capture_output=True,
                                            text=True,
                                        )
                                        if push_result.returncode == 0:
                                            print(f"{Colors.GREEN}✓ Pushed{Colors.NC}")
                                            print(f"{Colors.CYAN}Creating PR...{Colors.NC}")
                                            result = subprocess.run(
                                                ["gh", "pr", "create",
                                                 "--title", pr_title,
                                                 "--body", pr_desc,
                                                 "--base", base_branch,
                                                 "--head", new_branch],
                                                cwd=repo_path,
                                                capture_output=True,
                                                text=True,
                                            )
                                            if result.returncode == 0:
                                                print(f"  {Colors.GREEN}✓ PR created: {result.stdout.strip()}{Colors.NC}")
                                            else:
                                                print(f"  {Colors.RED}✗ PR failed: {result.stderr.strip()}{Colors.NC}")
                                        else:
                                            print(f"  {Colors.RED}✗ Push failed: {push_result.stderr.strip()}{Colors.NC}")
                                    else:
                                        print(f"{Colors.RED}✗ Checkout failed: {checkout_result.stderr.strip()}{Colors.NC}")
                                else:
                                    print(f"{Colors.YELLOW}No branch name entered.{Colors.NC}")
                            else:
                                target_branch = None
                                if branch_choice.isdigit():
                                    idx = int(branch_choice) - 1
                                    if 0 <= idx < len(remote_branches):
                                        target_branch = remote_branches[idx]
                                elif branch_choice.lower() not in ("n", "new", "more"):
                                    for rb in remote_branches:
                                        if rb.endswith(branch_choice) or rb == f"origin/{branch_choice}":
                                            target_branch = rb
                                            break
                                if target_branch:
                                    local_name = target_branch.replace("origin/", "")
                                    print(f"\n{Colors.CYAN}Creating local branch {local_name} from current HEAD (with commits)...{Colors.NC}")
                                    checkout_result = subprocess.run(
                                        ["git", "checkout", "-b", local_name],
                                        cwd=repo_path,
                                        capture_output=True,
                                        text=True,
                                    )
                                    if checkout_result.returncode == 0:
                                        print(f"{Colors.GREEN}✓ Created branch {local_name}{Colors.NC}")
                                        print(f"{Colors.CYAN}Pushing to remote...{Colors.NC}")
                                        push_result = subprocess.run(
                                            ["git", "push", "-u", "origin", local_name],
                                            cwd=repo_path,
                                            capture_output=True,
                                            text=True,
                                        )
                                        if push_result.returncode == 0:
                                            print(f"{Colors.GREEN}✓ Pushed{Colors.NC}")
                                            print(f"{Colors.CYAN}Creating PR...{Colors.NC}")
                                            result = subprocess.run(
                                                ["gh", "pr", "create",
                                                 "--title", pr_title,
                                                 "--body", pr_desc,
                                                 "--base", base_branch,
                                                 "--head", local_name],
                                                cwd=repo_path,
                                                capture_output=True,
                                                text=True,
                                            )
                                            if result.returncode == 0:
                                                print(f"  {Colors.GREEN}✓ PR created: {result.stdout.strip()}{Colors.NC}")
                                            else:
                                                print(f"  {Colors.RED}✗ PR failed: {result.stderr.strip()}{Colors.NC}")
                                        else:
                                            print(f"  {Colors.RED}✗ Push failed: {push_result.stderr.strip()}{Colors.NC}")
                                    else:
                                        print(f"{Colors.RED}✗ Checkout failed: {checkout_result.stderr.strip()}{Colors.NC}")
                                else:
                                    print(f"{Colors.RED}Invalid branch selection.{Colors.NC}")
                        except Exception as e:
                            print(f"{Colors.RED}Error listing branches: {e}{Colors.NC}")


if __name__ == "__main__":
    asyncio.run(main())
