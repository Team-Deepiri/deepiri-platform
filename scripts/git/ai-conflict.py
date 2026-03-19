#!/usr/bin/env python3
"""
AI-Powered Git Conflict Resolver for Deepiri Platform
Analyzes merge/rebase conflicts, uses AI to resolve them intelligently
Handles: conflict detection, 3-way merge analysis, AI-powered resolution, interactive review
"""
import asyncio
import os
import re
import subprocess
import sys
from typing import Optional

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


def is_ollama_running(base_url: str) -> bool:
    try:
        import urllib.request
        req = urllib.request.Request(f"{base_url}/api/tags")
        urllib.request.urlopen(req, timeout=2)
        return True
    except Exception:
        return False


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
    return os.path.isdir(os.path.join(path, ".git")) or os.path.isfile(os.path.join(path, ".git"))


def find_script_git_root() -> str:
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
    repos = []
    root_abs = os.path.abspath(root_path)

    root_name = os.path.basename(root_abs) or root_abs
    if is_git_repo(root_abs):
        repos.append({"path": root_abs, "name": root_name, "is_submodule": False})

    submodule_paths = parse_gitmodules(root_abs)
    for subpath in submodule_paths:
        full_path = os.path.join(root_abs, subpath)
        if is_git_repo(full_path):
            repos.append({
                "path": os.path.abspath(full_path),
                "name": os.path.basename(subpath),
                "is_submodule": True,
            })

    return repos


def get_conflict_files(repo_path: str) -> list[str]:
    try:
        result = subprocess.run(
            ["git", "diff", "--name-only", "--diff-filter=U"],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        return [f.strip() for f in result.stdout.strip().split("\n") if f.strip()]
    except Exception:
        return []


def get_merge_head(repo_path: str) -> str:
    try:
        merge_head = os.path.join(repo_path, ".git", "MERGE_HEAD")
        if os.path.isfile(merge_head):
            with open(merge_head, "r") as f:
                return f.read().strip()
    except Exception:
        pass
    return ""


def get_rebase_working_files(repo_path: str) -> list[str]:
    rebase_interactive = os.path.join(repo_path, ".git", "rebase-merge")
    rebase_apply = os.path.join(repo_path, ".git", "rebase-apply")
    
    if os.path.isdir(rebase_interactive):
        todo_file = os.path.join(rebase_interactive, "todo")
        if os.path.isfile(todo_file):
            try:
                with open(todo_file, "r") as f:
                    content = f.read()
                files = set()
                for line in content.split("\n"):
                    if line.strip() and not line.strip().startswith("#"):
                        parts = line.split()
                        if len(parts) >= 3 and parts[0] in ("pick", "reword", "edit"):
                            files.add(parts[2])
                return list(files)
            except Exception:
                pass
    
    return []


def get_conflict_marker_content(file_path: str) -> dict:
    try:
        with open(file_path, "r", errors="replace") as f:
            content = f.read()
    except Exception:
        return {"base": "", "ours": "", "theirs": "", "raw": ""}

    base = ""
    ours = ""
    theirs = ""
    
    sections = {"ours": [], "theirs": []}
    current = None
    
    for line in content.split("\n"):
        if line.startswith("<<<<<<< "):
            current = "ours"
            sections["ours"].append(line)
        elif line.startswith("======="):
            current = "theirs"
            sections["theirs"].append(line)
        elif line.startswith(">>>>>>> "):
            current = None
            sections["theirs"].append(line)
        else:
            if current == "ours":
                sections["ours"].append(line)
            elif current == "theirs":
                sections["theirs"].append(line)
            else:
                base += line + "\n"

    ours = "\n".join(sections["ours"])
    theirs = "\n".join(sections["theirs"])

    return {"base": base, "ours": ours, "theirs": theirs, "raw": content}


def get_file_at_commit(repo_path: str, file_path: str, commit: str) -> str:
    try:
        result = subprocess.run(
            ["git", "show", f"{commit}:{file_path}"],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            return result.stdout
    except Exception:
        pass
    return ""


async def send_to_ollama(base_url: str, model: str, prompt: str, system: str = "") -> str:
    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})

    payload = {
        "model": model,
        "messages": messages,
        "stream": False,
    }

    try:
        async with httpx.AsyncClient(timeout=180.0) as client:
            response = await client.post(f"{base_url}/api/chat", json=payload)
            response.raise_for_status()
            data = response.json()
            return data["message"]["content"]
    except Exception as e:
        print(f"{Colors.RED}Error sending request to Ollama: {e}{Colors.NC}")
        sys.exit(1)


async def resolve_conflict(
    base_url: str,
    model: str,
    file_path: str,
    ours_content: str,
    theirs_content: str,
    base_content: str = "",
) -> str:
    system_prompt = """You are resolving a git merge conflict. Given the "ours" (current branch) and "theirs" (incoming branch) versions, produce a resolved version.

Rules:
- Keep both changes if they're compatible (e.g., different functions, different files)
- For incompatible changes, choose the better implementation based on correctness and style
- Preserve comments that explain the code
- Use the existing code style (indentation, naming, etc.)
- Output ONLY the resolved file content - no explanations, no markdown
- If you cannot resolve confidently, keep both versions as comments"""

    user_prompt = f"""File: {file_path}

OURS (current branch - your changes):
```
{ours_content}
```

THEIRS (incoming changes):
```
{theirs_content}
```

{f"BASE (common ancestor):\n```\n{base_content}\n```" if base_content else ""}

Resolve this conflict and output ONLY the final resolved content."""

    response = await send_to_ollama(base_url, model, user_prompt, system=system_prompt)
    
    cleaned = re.sub(r"^```[a-z]*\n?", "", response.strip())
    cleaned = re.sub(r"\n?```$", "", cleaned)
    
    return cleaned


async def get_ollama_models(base_url: str) -> list:
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(f"{base_url}/api/tags")
            response.raise_for_status()
            data = response.json()
            return [m["name"] for m in data.get("models", [])]
    except Exception:
        return []


def stage_file(repo_path: str, file_path: str) -> bool:
    try:
        subprocess.run(["git", "add", file_path], cwd=repo_path, check=True)
        return True
    except subprocess.CalledProcessError:
        return False


def continue_rebase_or_merge(repo_path: str) -> bool:
    try:
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        
        if ".git/MERGE_HEAD" in result.stdout or "merge" in result.stdout:
            result = subprocess.run(
                ["git", "commit", "--no-edit"],
                cwd=repo_path,
                capture_output=True,
                text=True,
            )
            return result.returncode == 0
        
        if os.path.isdir(os.path.join(repo_path, ".git", "rebase-merge")):
            result = subprocess.run(
                ["git", "rebase", "--continue"],
                cwd=repo_path,
                capture_output=True,
                text=True,
            )
            return result.returncode == 0
            
        return False
    except Exception:
        return False


def abort_rebase_or_merge(repo_path: str) -> bool:
    try:
        if os.path.isdir(os.path.join(repo_path, ".git", "rebase-merge")):
            subprocess.run(["git", "rebase", "--abort"], cwd=repo_path, check=True)
        elif os.path.isfile(os.path.join(repo_path, ".git", "MERGE_HEAD")):
            subprocess.run(["git", "merge", "--abort"], cwd=repo_path, check=True)
        return True
    except Exception:
        return False


def get_local_branches(repo_path: str) -> list[str]:
    try:
        result = subprocess.run(
            ["git", "branch"],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        branches = []
        for line in result.stdout.strip().split("\n"):
            branch = line.strip().lstrip("* ").strip()
            if branch and not branch.startswith("(") and not branch.startswith("HEAD"):
                branches.append(branch)
        return branches
    except Exception:
        return []


def get_remote_branches(repo_path: str) -> list[str]:
    try:
        result = subprocess.run(
            ["git", "branch", "-r"],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        branches = []
        for line in result.stdout.strip().split("\n"):
            branch = line.strip()
            if branch and "HEAD" not in branch:
                branches.append(branch)
        return branches
    except Exception:
        return []


def fetch_all(repo_path: str) -> bool:
    try:
        subprocess.run(
            ["git", "fetch", "--all"],
            cwd=repo_path,
            capture_output=True,
            check=True,
        )
        return True
    except Exception:
        return False


def checkout_branch(repo_path: str, branch: str, create_new: bool = False) -> bool:
    try:
        if create_new:
            subprocess.run(
                ["git", "checkout", "-b", branch],
                cwd=repo_path,
                check=True,
            )
        else:
            subprocess.run(
                ["git", "checkout", branch],
                cwd=repo_path,
                check=True,
            )
        return True
    except subprocess.CalledProcessError:
        return False


def initiate_merge(repo_path: str, branch: str) -> bool:
    try:
        result = subprocess.run(
            ["git", "merge", branch],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        return result.returncode == 0 or "Merge" in result.stdout
    except Exception:
        return False


def initiate_rebase(repo_path: str, branch: str) -> bool:
    try:
        result = subprocess.run(
            ["git", "rebase", branch],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        return result.returncode == 0 or "Current branch" in result.stdout
    except Exception:
        return False


def get_current_branch(repo_path: str) -> str:
    try:
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        return result.stdout.strip()
    except Exception:
        return ""


def has_uncommitted_changes(repo_path: str) -> bool:
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


def confirm_resolution(file_path: str, resolved_content: str) -> bool:
    print(f"\n{Colors.CYAN}--- Resolved: {file_path} ---{Colors.NC}")
    lines = resolved_content.split("\n")
    preview = "\n".join(lines[:30])
    if len(lines) > 30:
        preview += f"\n{Colors.YELLOW}... ({len(lines) - 30} more lines){Colors.NC}"
    print(preview)
    
    response = input(f"\n{Colors.BLUE}[y] Accept  [e] Edit  [s] Skip  [a] Accept all: {Colors.NC}").strip().lower()
    
    if response == "y" or response == "a":
        return True
    elif response == "e":
        editor = os.getenv("EDITOR", "vim")
        temp_file = file_path + ".tmp"
        with open(temp_file, "w") as f:
            f.write(resolved_content)
        subprocess.run([editor, temp_file])
        with open(temp_file, "r") as f:
            resolved_content = f.read()
        os.remove(temp_file)
        with open(file_path, "w") as f:
            f.write(resolved_content)
        return True
    return False


async def run_interactive(repo: dict, root_path: str, ollama_url: str):
    repo_path = repo["path"]
    repo_name = repo["name"]

    while True:
        current_branch = get_current_branch(repo_path)
        has_changes = has_uncommitted_changes(repo_path)
        conflict_files = get_conflict_files(repo_path)
        in_merge = os.path.isfile(os.path.join(repo_path, ".git", "MERGE_HEAD"))
        in_rebase = os.path.isdir(os.path.join(repo_path, ".git", "rebase-merge"))

        print(f"\n{Colors.CYAN}Repository: {repo_name}{Colors.NC}")
        print(f"  {Colors.BLUE}Branch:{Colors.NC} {current_branch or '(detached)'}")
        if has_changes:
            print(f"  {Colors.YELLOW}! Uncommitted changes{Colors.NC}")
        if in_merge:
            print(f"  {Colors.YELLOW}! Merge in progress{Colors.NC}")
        if in_rebase:
            print(f"  {Colors.YELLOW}! Rebase in progress{Colors.NC}")
        if conflict_files:
            print(f"  {Colors.RED}! {len(conflict_files)} conflict(s){Colors.NC}")

        if conflict_files:
            print(f"\n{Colors.CYAN}r) Resolve conflicts  [b] Back to repo select  [q] Quit: {Colors.NC}", end="")
            action = input().strip().lower()
            if action == "q":
                return False
            elif action == "b":
                return True
            elif action != "r":
                continue

            await resolve_conflicts_interactive(repo_path, repo_name, ollama_url, root_path, in_merge, in_rebase)
        else:
            print(f"\n{Colors.CYAN}Actions:{Colors.NC}")
            print(f"  {Colors.BLUE}l{Colors.NC}) List all branches")
            print(f"  {Colors.GREEN}c{Colors.NC}) Switch/checkout branch")
            print(f"  {Colors.GREEN}f{Colors.NC}) Fetch all remotes")
            print(f"  {Colors.GREEN}m{Colors.NC}) Merge branch into current")
            print(f"  {Colors.GREEN}rb{Colors.NC}) Rebase onto branch")
            print(f"  {Colors.BLUE}b{Colors.NC}) Back to repo select")
            print(f"  {Colors.YELLOW}q{Colors.NC}) Quit")
            
            if in_merge or in_rebase:
                print(f"  {Colors.RED}!{Colors.NC}) Abort merge/rebase")
            
            print(f"\n{Colors.CYAN}Select action [l/c/m/rb]: {Colors.NC}", end="")
            action = input().strip().lower()
            
            if action == "q":
                return False
            elif action == "b":
                return True
            elif action == "l":
                print(f"\n{Colors.CYAN}All branches:{Colors.NC}")
                local = get_local_branches(repo_path)
                remote = get_remote_branches(repo_path)
                
                print(f"\n{Colors.GREEN}Local branches:{Colors.NC}")
                if current_branch:
                    for i, b in enumerate(local):
                        marker = " *" if b == current_branch else ""
                        print(f"  {i + 1}) {b}{marker}")
                else:
                    detached_commit = subprocess.run(
                        ["git", "rev-parse", "--short", "HEAD"],
                        cwd=repo_path,
                        capture_output=True,
                        text=True,
                    ).stdout.strip() or "unknown"
                    print(f"  {Colors.YELLOW}! HEAD detached at {detached_commit}{Colors.NC}")
                    for i, b in enumerate(local):
                        print(f"  {i + 1}) {b}")
                
                if remote:
                    print(f"\n{Colors.CYAN}Remote branches:{Colors.NC}")
                    for i, b in enumerate(remote, start=len(local) + 1):
                        print(f"  {i}) {b}")
                print("")
                continue
            elif action == "f":
                print(f"\n{Colors.CYAN}Fetching all remotes...{Colors.NC}")
                if fetch_all(repo_path):
                    print(f"{Colors.GREEN}✓ Fetch complete{Colors.NC}")
                else:
                    print(f"{Colors.RED}✗ Fetch failed{Colors.NC}")
                continue
            elif action == "c":
                local = get_local_branches(repo_path)
                remote = get_remote_branches(repo_path)
                
                print(f"\n{Colors.CYAN}Local branches:{Colors.NC}")
                if current_branch:
                    for i, b in enumerate(local):
                        marker = " *" if b == current_branch else ""
                        print(f"  {i + 1}) {b}{marker}")
                else:
                    detached_commit = subprocess.run(
                        ["git", "rev-parse", "--short", "HEAD"],
                        cwd=repo_path,
                        capture_output=True,
                        text=True,
                    ).stdout.strip() or "unknown"
                    print(f"  {Colors.YELLOW}! HEAD detached at {detached_commit}{Colors.NC}")
                    for i, b in enumerate(local):
                        print(f"  {i + 1}) {b}")
                
                if remote:
                    print(f"\n{Colors.CYAN}Remote branches:{Colors.NC}")
                    for i, b in enumerate(remote, start=len(local) + 1):
                        print(f"  {i}) {b}")
                
                print(f"\n{Colors.CYAN}Branch name (or number, or 'new' for new branch): {Colors.NC}", end="")
                branch_input = input().strip()
                
                if branch_input == "new":
                    print(f"{Colors.CYAN}New branch name: {Colors.NC}", end="")
                    new_branch = input().strip()
                    if new_branch:
                        if checkout_branch(repo_path, new_branch, create_new=True):
                            print(f"{Colors.GREEN}✓ Created and switched to {new_branch}{Colors.NC}")
                        else:
                            print(f"{Colors.RED}✗ Failed to create branch{Colors.NC}")
                    continue
                elif branch_input.isdigit():
                    idx = int(branch_input) - 1
                    all_branches = local + remote
                    if 0 <= idx < len(all_branches):
                        branch_input = all_branches[idx]
                    else:
                        print(f"{Colors.RED}Invalid selection{Colors.NC}")
                        continue
                
                if branch_input.startswith("origin/"):
                    local_name = branch_input.replace("origin/", "")
                    if checkout_branch(repo_path, local_name):
                        print(f"{Colors.GREEN}✓ Switched to {local_name}{Colors.NC}")
                    else:
                        print(f"{Colors.YELLOW}Creating local branch {local_name}...{Colors.NC}")
                        result = subprocess.run(
                            ["git", "checkout", "-b", local_name, branch_input],
                            cwd=repo_path,
                            capture_output=True,
                            text=True,
                        )
                        if result.returncode == 0:
                            print(f"{Colors.GREEN}✓ Created {local_name} tracking {branch_input}{Colors.NC}")
                        else:
                            print(f"{Colors.RED}✗ Failed: {result.stderr}{Colors.NC}")
                else:
                    if checkout_branch(repo_path, branch_input):
                        print(f"{Colors.GREEN}✓ Switched to {branch_input}{Colors.NC}")
                    else:
                        print(f"{Colors.RED}✗ Failed to checkout {branch_input}{Colors.NC}")
                continue
            elif action == "m":
                print(f"\n{Colors.CYAN}Merge which branch? (or 'fetch' first): {Colors.NC}", end="")
                branch_to_merge = input().strip()
                if not branch_to_merge:
                    continue
                if branch_to_merge == "fetch":
                    fetch_all(repo_path)
                    print(f"{Colors.CYAN}Now enter branch to merge: {Colors.NC}", end="")
                    branch_to_merge = input().strip()
                    if not branch_to_merge:
                        continue
                
                remote_branches = get_remote_branches(repo_path)
                full_branch = branch_to_merge
                local_branches = get_local_branches(repo_path)
                if not any(b.endswith(branch_to_merge) for b in local_branches):
                    for rb in remote_branches:
                        if rb.endswith(branch_to_merge):
                            full_branch = rb
                            break
                
                if has_changes:
                    print(f"{Colors.YELLOW}Stashing uncommitted changes...{Colors.NC}")
                    subprocess.run(["git", "stash"], cwd=repo_path, capture_output=True)
                
                print(f"\n{Colors.CYAN}Merging {full_branch} into {current_branch}...{Colors.NC}")
                if not initiate_merge(repo_path, full_branch):
                    print(f"{Colors.YELLOW}Merge initiated (check for conflicts){Colors.NC}")
                
                conflict_files = get_conflict_files(repo_path)
                
                if not conflict_files:
                    print(f"{Colors.GREEN}✓ No conflicts! Merge complete.{Colors.NC}")
                    if has_changes:
                        subprocess.run(["git", "stash", "pop"], cwd=repo_path, capture_output=True)
                else:
                    print(f"{Colors.YELLOW}Merge initiated with conflicts. Resolving...{Colors.NC}")
                continue
            elif action == "rb":
                print(f"\n{Colors.CYAN}Rebase onto which branch? (or 'fetch' first): {Colors.NC}", end="")
                branch_to_rebase = input().strip()
                if not branch_to_rebase:
                    continue
                if branch_to_rebase == "fetch":
                    fetch_all(repo_path)
                    print(f"{Colors.CYAN}Now enter branch to rebase onto: {Colors.NC}", end="")
                    branch_to_rebase = input().strip()
                    if not branch_to_rebase:
                        continue
                
                remote_branches = get_remote_branches(repo_path)
                full_branch = branch_to_rebase
                local_branches = get_local_branches(repo_path)
                if not any(b.endswith(branch_to_rebase) for b in local_branches):
                    for rb in remote_branches:
                        if rb.endswith(branch_to_rebase):
                            full_branch = rb
                            break
                
                if has_changes:
                    print(f"{Colors.YELLOW}Stashing uncommitted changes...{Colors.NC}")
                    subprocess.run(["git", "stash"], cwd=repo_path, capture_output=True)
                
                print(f"\n{Colors.CYAN}Rebasing onto {full_branch}...{Colors.NC}")
                if not initiate_rebase(repo_path, full_branch):
                    print(f"{Colors.YELLOW}Rebase initiated (check for conflicts){Colors.NC}")
                
                conflict_files = get_conflict_files(repo_path)
                
                if not conflict_files:
                    print(f"{Colors.GREEN}✓ No conflicts! Rebase complete.{Colors.NC}")
                    if has_changes:
                        subprocess.run(["git", "stash", "pop"], cwd=repo_path, capture_output=True)
                else:
                    print(f"{Colors.YELLOW}Rebase initiated with conflicts. Resolving...{Colors.NC}")
                continue
            elif action == "!":
                if abort_rebase_or_merge(repo_path):
                    print(f"{Colors.GREEN}✓ Aborted{Colors.NC}")
                else:
                    print(f"{Colors.RED}✗ Failed to abort{Colors.NC}")
                continue
            else:
                print(f"{Colors.RED}Invalid action{Colors.NC}")
                continue


async def resolve_conflicts_interactive(repo_path: str, repo_name: str, ollama_url: str, root_path: str, in_merge: bool, in_rebase: bool):
    conflict_files = get_conflict_files(repo_path)
    
    if not conflict_files:
        print(f"{Colors.GREEN}No conflicts remaining!{Colors.NC}")
        return

    if not is_ollama_running(ollama_url):
        print(f"\n{Colors.YELLOW}Ollama is not running.{Colors.NC}")
        print(f"{Colors.CYAN}[s] Start automatically  [m] Pull models  [b] Back: {Colors.NC}", end="")
        response = input().strip().lower()
        if response == "s":
            if not start_ollama(root_path, ollama_url):
                print(f"{Colors.RED}Could not start Ollama. Please start it manually.{Colors.NC}")
                return
        elif response == "m":
            check_script = find_check_ollama_script(root_path)
            if check_script:
                print(f"\n{Colors.CYAN}Running check-ollama-models.sh...{Colors.NC}")
                subprocess.run([check_script], cwd=root_path)
            else:
                print(f"{Colors.YELLOW}check-ollama-models.sh not found.{Colors.NC}")
            return
        elif response == "b":
            return
        else:
            return

    async with Spinner(f"Connecting to Ollama at {ollama_url}..."):
        models = await get_ollama_models(ollama_url)
    
    if not models:
        print(f"{Colors.YELLOW}No models found in Ollama.{Colors.NC}")
        print(f"{Colors.RED}No models available.{Colors.NC}")
        return

    if len(models) == 1:
        model = models[0]
    else:
        print(f"\n{Colors.GREEN}Available models:{Colors.NC}")
        for i, m in enumerate(models):
            print(f"  {i + 1}) {m}")
        print(f"\n{Colors.CYAN}Select model [1]: {Colors.NC}", end="")
        model_input = input().strip()
        model = models[int(model_input) - 1] if model_input.isdigit() else models[0]

    print(f"{Colors.GREEN}Using model: {model}{Colors.NC}\n")

    merge_head = get_merge_head(repo_path)
    auto_resolve = "-y" in sys.argv or "--yes" in sys.argv
    
    resolved_count = 0
    skipped_count = 0
    
    print(f"{Colors.CYAN}Resolving conflicts...{Colors.NC}\n")

    for i, file_path in enumerate(conflict_files):
        full_path = os.path.join(repo_path, file_path)
        
        if not os.path.isfile(full_path):
            print(f"{Colors.YELLOW}Skipping {file_path} - file not found{Colors.NC}")
            continue

        conflict_data = get_conflict_marker_content(full_path)
        ours_content = conflict_data["ours"]
        theirs_content = conflict_data["theirs"]
        
        if not ours_content or not theirs_content:
            print(f"{Colors.YELLOW}! {file_path} - no clear conflict markers found")
            continue

        base_content = ""
        if merge_head:
            base_content = get_file_at_commit(repo_path, file_path, f"{merge_head}^")

        async with Spinner(f"Resolving {file_path}...") as spinner:
            resolved_content = await resolve_conflict(
                base_url=ollama_url,
                model=model,
                file_path=file_path,
                ours_content=ours_content,
                theirs_content=theirs_content,
                base_content=base_content,
            )

        if auto_resolve or confirm_resolution(file_path, resolved_content):
            with open(full_path, "w") as f:
                f.write(resolved_content)
            
            if stage_file(repo_path, file_path):
                print(f"{Colors.GREEN}✓{Colors.NC} Resolved: {file_path}")
                resolved_count += 1
            else:
                print(f"{Colors.RED}✗{Colors.NC} Failed to stage: {file_path}")
        else:
            print(f"{Colors.YELLOW}⊘{Colors.NC} Skipped: {file_path}")
            skipped_count += 1

    print(f"\n{Colors.CYAN}{'='*60}{Colors.NC}")
    print(f"{Colors.GREEN}Conflict resolution complete!{Colors.NC}")
    print(f"  Resolved: {Colors.GREEN}{resolved_count}{Colors.NC}")
    if skipped_count > 0:
        print(f"  Skipped: {Colors.YELLOW}{skipped_count}{Colors.NC}")
    print(f"{Colors.CYAN}{'='*60}{Colors.NC}")

    if resolved_count > 0:
        print(f"\n{Colors.CYAN}Continue merge/rebase? [y/N]: {Colors.NC}", end="")
        if input().strip().lower() == "y":
            if continue_rebase_or_merge(repo_path):
                print(f"{Colors.GREEN}✓ Merge/rebase completed{Colors.NC}")
            else:
                print(f"{Colors.YELLOW}! Could not auto-continue. Run 'git commit' or 'git rebase --continue' manually.{Colors.NC}")
        else:
            print(f"{Colors.CYAN}Run 'git commit' to complete merge or 'git rebase --continue' for rebase.{Colors.NC}")
    
    print(f"\n{Colors.CYAN}To abort and revert: git merge --abort  or  git rebase --abort{Colors.NC}")


async def main():
    auto_resolve = "-y" in sys.argv or "--yes" in sys.argv
    ollama_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
    root_path = find_script_git_root()

    print(f"{Colors.CYAN}╔{'═'*56}╗{Colors.NC}")
    print(f"{Colors.CYAN}║{' AI Conflict Resolver (Deepiri) ':^56}║{Colors.NC}")
    print(f"{Colors.CYAN}╚{'═'*56}╝{Colors.NC}\n")

    repos = find_git_repos(root_path)
    
    if not repos:
        print(f"{Colors.RED}No git repositories found.{Colors.NC}")
        sys.exit(1)

    while True:
        print(f"{Colors.CYAN}Select repository:{Colors.NC}")
        for i, repo in enumerate(repos):
            print(f"  {i + 1}) {repo['name']}")
        print(f"\n{Colors.CYAN}[1-{len(repos)}] (or 'q' to quit): {Colors.NC}", end="")
        
        selection_input = input().strip().lower()
        if selection_input == "q":
            break
        
        try:
            selection = int(selection_input) - 1
            if selection < 0 or selection >= len(repos):
                print(f"{Colors.RED}Invalid selection.{Colors.NC}")
                continue
        except ValueError:
            print(f"{Colors.RED}Invalid input.{Colors.NC}")
            continue
        
        repo = repos[selection]
        
        should_exit = await run_interactive(repo, root_path, ollama_url)
        if should_exit is False:
            break


if __name__ == "__main__":
    asyncio.run(main())
