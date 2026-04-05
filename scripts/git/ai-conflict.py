#!/usr/bin/env python3
"""
AI-Powered Git Conflict Resolver for Deepiri Platform
Analyzes branch differences and resolves conflicts with AI assistance.

Features:
- Compare any two branches before merging
- Preview conflicts without merging
- AI-powered conflict resolution with best practices research
- Accept-all or review-each mode with explanations
- Beginner-friendly hints throughout
"""
import asyncio
import json
import os
import re
import subprocess
import sys
import tempfile
import shutil
from functools import lru_cache
from typing import Optional

import difflib

try:
    import httpx
except ImportError:
    print("Error: httpx library required. Install with: pip install httpx")
    sys.exit(1)



class Colors:
    GREEN = "\033[0;32m"
    RED = "\033[0;31m"
    BOLD = "\033[1m"
    YELLOW = "\033[1;33m"
    BLUE = "\033[0;34m"
    CYAN = "\033[0;36m"
    MAGENTA = "\033[0;35m"
    GRAY = "\033[0;90m"
    NC = "\033[0m"

    @classmethod
    def hint(cls, text: str) -> str:
        return f"{cls.GRAY}{text}{cls.NC}"


class Hints:
    HINT = Colors.GRAY

    MERGE = """
┌─ HINT: What is a Merge? ─────────────────────────────────────────────┐
│ A merge combines two branches by joining their histories.           │
│ Git tries to auto-combine changes, but if both branches modified   │
│ the same lines, you get a "conflict" that needs manual resolution.  │
│ The base branch stays unchanged; a merge commit joins both histories.│
└─────────────────────────────────────────────────────────────────────┘
"""

    REBASE = """
┌─ HINT: What is a Rebase? ───────────────────────────────────────────┐
│ Rebase "replays" your changes on top of another branch.            │
│ It creates a cleaner, linear history instead of merge commits.    │
│ WARNING: Avoid rebasing branches that others have based work on!   │
└─────────────────────────────────────────────────────────────────────┘
"""

    COMPARE = """
┌─ HINT: Comparing Branches ──────────────────────────────────────────┐
│ This shows what files are different between two branches.         │
│ It's like a "preview" before you actually merge - no changes made! │
│ Useful to see if there will be conflicts before committing.        │
└─────────────────────────────────────────────────────────────────────┘
"""

    RESOLVE = """
┌─ HINT: Resolving Conflicts ──────────────────────────────────────────┐
│ When Git can't auto-merge, it marks conflicting sections with:     │
│   <<<<<<< HEAD (your branch)                                       │
│   your code                                                        │
│   =======                                                           │
│   their code                                                       │
│   >>>>>>> branch-name                                               │
│ You (or AI) must decide which code to keep, or combine both.       │
└─────────────────────────────────────────────────────────────────────┘
"""

    ACCEPT_ALL = """
┌─ HINT: Accept All Mode ─────────────────────────────────────────────┐
│ AI will resolve ALL conflicts automatically.                       │
│ Uses best practices research to make smart decisions.              │
│ Fastest option - good for many similar conflicts.                   │
└─────────────────────────────────────────────────────────────────────┘
"""

    REVIEW = """
┌─ HINT: Review Each Mode ────────────────────────────────────────────┐
│ AI resolves one conflict at a time and explains WHY it chose      │
│ the solution. You can accept, edit, or skip each one.              │
│ Best for learning or critical code you want to verify.             │
└─────────────────────────────────────────────────────────────────────┘
"""

    PUSH = """
┌─ HINT: What is Push? ──────────────────────────────────────────────┐
│ Push sends your local commits to the remote repository (e.g., GitHub)│
│ After resolving conflicts, you must push to share your changes.    │
│ Use 'git push -u origin branch-name' for new branches.              │
└─────────────────────────────────────────────────────────────────────┘
"""


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
                    print(f"{Colors.GREEN}Ollama started{Colors.NC}")
                    return True
            print(f"{Colors.RED}Failed to start Ollama{Colors.NC}")
            return False
        except Exception as e:
            print(f"{Colors.RED}Failed to start Ollama: {e}{Colors.NC}")
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
                print(f"{Colors.RED}Docker compose failed: {result.stderr}{Colors.NC}")
                return False
            
            import time
            for _ in range(30):
                time.sleep(1)
                if is_ollama_running(base_url):
                    print(f"{Colors.GREEN}Ollama started (docker){Colors.NC}")
                    return True
            print(f"{Colors.YELLOW}Ollama container may still be starting...{Colors.NC}")
            return True
        except Exception as e:
            print(f"{Colors.RED}Failed to start Ollama: {e}{Colors.NC}")
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


def find_git_repos(root_path: str) -> list[dict]:
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


def is_submodule_path(repo_path: str, file_path: str) -> bool:
    """Check if a conflict path corresponds to a submodule (not a regular file)."""
    full_path = os.path.join(repo_path, file_path)
    if os.path.isdir(full_path):
        return True
    # Also check via git ls-files -u -- the mode 160000 means submodule
    try:
        result = subprocess.run(
            ["git", "ls-files", "-u", "--", file_path],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        for line in result.stdout.strip().split("\n"):
            if line.startswith("160000"):
                return True
    except Exception:
        pass
    return False


def resolve_submodule_conflict(repo_path: str, file_path: str) -> bool:
    """Resolve a submodule pointer conflict by picking the commit with the latest timestamp."""
    try:
        result = subprocess.run(
            ["git", "ls-files", "-u", "--", file_path],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        # Lines look like: "160000 <hash> <stage>\t<path>"
        # stage 2 = ours, stage 3 = theirs
        candidates = {}
        for line in result.stdout.strip().split("\n"):
            if not line:
                continue
            parts = line.split()
            if len(parts) >= 3 and parts[0] == "160000":
                commit_hash = parts[1]
                stage = parts[2].rstrip("\t")
                if stage in ("2", "3"):
                    candidates[stage] = commit_hash

        if not candidates:
            return False

        # Get commit timestamps for each candidate
        def get_commit_time(hash_val: str) -> int:
            try:
                r = subprocess.run(
                    ["git", "log", "--format=%ct", "-1", hash_val],
                    cwd=repo_path,
                    capture_output=True,
                    text=True,
                )
                return int(r.stdout.strip()) if r.returncode == 0 and r.stdout.strip() else 0
            except Exception:
                return 0

        best_hash = None
        best_time = -1
        for stage, hash_val in candidates.items():
            t = get_commit_time(hash_val)
            if t > best_time:
                best_time = t
                best_hash = hash_val

        if not best_hash:
            # Fall back to "theirs" (stage 3) if we can't determine timestamps
            best_hash = candidates.get("3") or candidates.get("2")

        subprocess.run(
            ["git", "update-index", "--cacheinfo", f"160000,{best_hash},{file_path}"],
            cwd=repo_path,
            capture_output=True,
        )
        return True
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


def checkout_branch(repo_path: str, branch: str) -> bool:
    try:
        subprocess.run(["git", "checkout", branch], cwd=repo_path, check=True)
        return True
    except subprocess.CalledProcessError:
        return False


def resolve_branch_ref(repo_path: str, branch: str) -> str:
    """Resolve a branch name to a valid git ref.
    Always prefers origin/<branch> (remote tracking ref, fresh after fetch)
    over a local branch that may be stale and behind.
    """
    def verify(ref):
        return subprocess.run(
            ["git", "rev-parse", "--verify", ref],
            cwd=repo_path, capture_output=True, text=True
        ).returncode == 0

    # Already has a remote prefix — use as-is
    if branch.startswith("origin/") or branch.startswith("remotes/"):
        return branch

    # Prefer remote tracking ref over a potentially stale local branch
    remote_ref = f"origin/{branch}"
    if verify(remote_ref):
        return remote_ref

    # Fall back to local branch / tag / SHA
    if verify(branch):
        return branch

    return branch  # let git report the error downstream


def get_conflicting_files_between_branches(repo_path: str, head_branch: str, base_branch: str) -> dict | None:
    """Get files that would conflict merging base_branch into head_branch.

    Uses two independent methods and unions the results:
      1. git merge-tree --write-tree  (in-memory 3-way merge, git >= 2.38)
         Parses unmerged index entries (stage 1/2/3) for true content/submodule conflicts.
      2. Isolated worktree + git merge  (fallback and supplement)
         Catches submodule conflicts that merge-tree can miss (e.g. diverged but fast-forwardable).
      3. Deletion check  (independent of both)
         Files deleted in head_branch but still present in base_branch — GitHub flags these
         as conflicts because the merge would silently remove them from base.

    Returns None if refs are invalid.
    Returns dict:
      'true_conflicts' – sorted list of files needing resolution
    """
    def run(cmd, cwd=None):
        return subprocess.run(cmd, cwd=cwd or repo_path, capture_output=True, text=True)

    head_branch = resolve_branch_ref(repo_path, head_branch)
    base_branch = resolve_branch_ref(repo_path, base_branch)

    for ref in (head_branch, base_branch):
        if run(["git", "rev-parse", "--verify", ref]).returncode != 0:
            return None

    conflicts: set[str] = set()

    # ── Method 1: git merge-tree --write-tree (in-memory, no worktree needed) ──
    # Unmerged index entries have the format:
    #   <mode> <sha> <stage>\t<path>   where stage ∈ {1=ancestor, 2=ours, 3=theirs}
    # Any path that appears at stage 1, 2, or 3 is a genuine conflict.
    mt = run(["git", "merge-tree", "--write-tree", "--messages", head_branch, base_branch])
    lines = (mt.stdout + mt.stderr).splitlines()
    for line in lines:
        # Index entries start with a 6-digit mode followed by a space
        if len(line) > 7 and line[:6].isdigit() and line[6] == " ":
            parts = line.split("\t", 1)
            if len(parts) == 2:
                path = parts[1].strip().strip('"')
                if path:
                    conflicts.add(path)
        # Also capture any CONFLICT lines from the messages section
        m = re.search(r"CONFLICT[^:]*:\s+(?:Merge conflict in\s+)?(\S+)", line)
        if m:
            conflicts.add(m.group(1).strip().strip('"'))

    # ── Method 2: worktree merge (supplements merge-tree for submodule edge cases) ──
    tmpdir = tempfile.mkdtemp(prefix="ai-conflict-chk-")
    try:
        if run(["git", "worktree", "add", "--detach", tmpdir, head_branch]).returncode == 0:
            merge_out = run(["git", "merge", "--no-commit", "--no-ff", base_branch], cwd=tmpdir)

            # CONFLICT lines from merge output
            for line in (merge_out.stdout + merge_out.stderr).splitlines():
                m = re.search(r"CONFLICT[^:]*:\s+(?:Merge conflict in\s+)?(\S+)", line)
                if m:
                    conflicts.add(m.group(1).strip().strip('"'))

            # Unmerged index entries from the worktree
            for line in run(["git", "ls-files", "-u"], cwd=tmpdir).stdout.splitlines():
                parts = line.split("\t", 1)
                if len(parts) == 2:
                    conflicts.add(parts[1].strip().strip('"'))

            # git status UU/DU/UD/AA/DD entries
            for line in run(["git", "status", "--short"], cwd=tmpdir).stdout.splitlines():
                if len(line) >= 3:
                    xy, path = line[:2], line[3:].strip().strip('"')
                    if ("U" in xy or xy in ("AA", "DD")) and path:
                        conflicts.add(path)
    except Exception:
        pass
    finally:
        run(["git", "merge", "--abort"], cwd=tmpdir)
        run(["git", "worktree", "remove", "--force", tmpdir])
        shutil.rmtree(tmpdir, ignore_errors=True)

    # ── Method 3: deletion conflicts ──
    # Two sub-cases:
    #   a) MODIFY/DELETE: deleted in head_branch AND modified in base_branch since the merge-base.
    #      This is a genuine conflict — one side deleted, the other made changes worth preserving.
    #      These are usually already caught by methods 1 and 2, but we add them for completeness.
    #   b) CLEAN DELETE: deleted in head_branch, base_branch has it unchanged from the merge-base.
    #      Git auto-resolves silently. Not a conflict — tracked separately as deletion_warnings.
    deletion_warnings: list[str] = []
    mb_r = run(["git", "merge-base", base_branch, head_branch])
    if mb_r.returncode == 0:
        mb = mb_r.stdout.strip()
        if mb:
            head_deleted = set(filter(None,
                run(["git", "diff", "--name-only", "--diff-filter=D", mb, head_branch]).stdout.splitlines()))
            base_modified = set(filter(None,
                run(["git", "diff", "--name-only", mb, base_branch]).stdout.splitlines()))
            for f in sorted(head_deleted):
                if run(["git", "cat-file", "-e", f"{base_branch}:{f}"]).returncode != 0:
                    continue  # already gone in base too
                if f in base_modified:
                    conflicts.add(f)   # modify/delete → true conflict
                elif f not in conflicts:
                    deletion_warnings.append(f)   # clean delete → informational

    return {"true_conflicts": sorted(conflicts), "deletion_warnings": deletion_warnings}


def get_file_diff_between_branches(repo_path: str, branch1: str, branch2: str) -> dict:
    try:
        result = subprocess.run(
            ["git", "diff", "--stat", f"{branch1}...{branch2}"],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        
        diff_result = subprocess.run(
            ["git", "diff", "--name-only", f"{branch1}...{branch2}"],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        
        files = [f.strip() for f in diff_result.stdout.strip().split("\n") if f.strip()]
        
        return {
            "success": True,
            "summary": result.stdout,
            "files": files,
            "count": len(files)
        }
    except Exception as e:
        return {"success": False, "error": str(e), "files": [], "count": 0}


def predict_conflicts(repo_path: str, head_branch: str, base_branch: str) -> dict:
    try:
        result = subprocess.run(
            ["git", "merge-tree", "--write-tree", base_branch, head_branch],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        
        if result.returncode == 0:
            return {
                "would_conflict": False,
                "message": "No conflicts predicted - merge should work cleanly",
                "files": []
            }
        
        conflict_files = []
        stderr = result.stderr
        
        result_names = subprocess.run(
            ["git", "diff", "--name-only", "--diff-filter=U",
             f"{base_branch}...{head_branch}"],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        conflict_files = [f.strip() for f in result_names.stdout.strip().split("\n") if f.strip()]
        
        return {
            "would_conflict": len(conflict_files) > 0,
            "message": f"Potential conflicts in {len(conflict_files)} file(s)" if conflict_files else "Merge should be clean",
            "files": conflict_files
        }
    except Exception as e:
        return {
            "would_conflict": False,
            "message": f"Could not predict conflicts: {e}",
            "files": []
        }


def get_branch_file_content(repo_path: str, branch: str, file_path: str) -> str:
    try:
        result = subprocess.run(
            ["git", "show", f"{branch}:{file_path}"],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            return result.stdout
    except Exception:
        pass
    return ""


@lru_cache(maxsize=64)
def get_merge_base(repo_path: str, branch1: str, branch2: str) -> str:
    try:
        result = subprocess.run(
            ["git", "merge-base", branch1, branch2],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception:
        pass
    return ""


def get_file_diff_hunks(repo_path: str, branch1: str, branch2: str, file_path: str) -> str:
    try:
        result = subprocess.run(
            ["git", "diff", branch1, branch2, "--", file_path],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            return result.stdout
    except Exception:
        pass
    return ""


def colorize_resolved(head_content: str, base_content: str, resolved_content: str) -> list[str]:
    """Color each resolved line by origin: blue=HEAD, green=BASE, cyan=AI combined, plain=unchanged."""
    head_lines = head_content.splitlines()
    base_lines = base_content.splitlines()
    resolved_lines = resolved_content.splitlines()

    sm_head = difflib.SequenceMatcher(None, head_lines, resolved_lines, autojunk=False)
    head_matches: set[int] = set()
    for block in sm_head.get_matching_blocks():
        for i in range(block.size):
            head_matches.add(block.b + i)

    sm_base = difflib.SequenceMatcher(None, base_lines, resolved_lines, autojunk=False)
    base_matches: set[int] = set()
    for block in sm_base.get_matching_blocks():
        for i in range(block.size):
            base_matches.add(block.b + i)

    colored = []
    for i, line in enumerate(resolved_lines):
        in_head = i in head_matches
        in_base = i in base_matches
        if in_head and in_base:
            colored.append(line)
        elif in_head:
            colored.append(f"{Colors.BLUE}{line}{Colors.NC}")
        elif in_base:
            colored.append(f"{Colors.GREEN}{line}{Colors.NC}")
        else:
            colored.append(f"{Colors.CYAN}{line}{Colors.NC}")
    return colored


def print_side_by_side_diff(head_content: str, base_content: str, head_label: str = "HEAD", base_label: str = "BASE"):
    """Print a unified diff between head and base versions so you can see exactly what each branch has."""
    head_lines = (head_content or "").splitlines(keepends=True)
    base_lines = (base_content or "").splitlines(keepends=True)
    diff = list(difflib.unified_diff(
        base_lines, head_lines,
        fromfile=f"BASE ({base_label})", tofile=f"HEAD ({head_label})",
        lineterm="",
    ))
    if not diff:
        print(f"  {Colors.GRAY}(files are identical){Colors.NC}")
        return
    for line in diff[:80]:
        if line.startswith("+++") or line.startswith("---") or line.startswith("@@"):
            print(f"{Colors.CYAN}{line}{Colors.NC}")
        elif line.startswith("+"):
            print(f"{Colors.GREEN}{line}{Colors.NC}")
        elif line.startswith("-"):
            print(f"{Colors.RED}{line}{Colors.NC}")
        else:
            print(f"{Colors.GRAY}{line}{Colors.NC}")
    if len(diff) > 80:
        print(f"{Colors.GRAY}... ({len(diff) - 80} more diff lines — use [d] to view all){Colors.NC}")


def review_and_decide(result: dict) -> str:
    """Show raw diff + AI explanation + colorized preview. Returns 'y', 'a', 's', 'e', 'o', or 't'."""
    head_content = result.get("head", "")
    base_content = result.get("base_branch_version", "")

    # Show the raw diff between the two branch versions first
    print(f"\n{Colors.CYAN}--- Raw Diff (BASE vs HEAD) ---{Colors.NC}")
    print_side_by_side_diff(head_content, base_content)

    if result.get("explanation"):
        print(f"\n{Colors.CYAN}--- AI Explanation ---{Colors.NC}")
        print(f"{Colors.GRAY}{result['explanation']}{Colors.NC}")

    colored = colorize_resolved(head_content, base_content, result["content"])
    legend = (
        f"{Colors.GRAY}("
        f"{Colors.BLUE}blue{Colors.GRAY}=HEAD kept  "
        f"{Colors.GREEN}green{Colors.GRAY}=BASE kept  "
        f"{Colors.CYAN}cyan{Colors.GRAY}=AI combined){Colors.NC}"
    )
    print(f"\n{Colors.CYAN}--- AI Resolved Preview --- {legend}")

    full_diff = None  # lazy-load for [d]

    while True:
        for line in colored[:30]:
            print(line)
        remaining = len(colored) - 30
        if remaining > 0:
            print(f"{Colors.GRAY}... ({remaining} more lines){Colors.NC}")

        print(
            f"\n{Colors.CYAN}"
            f"[y] Accept AI  [o] Keep OURS (HEAD)  [t] Keep THEIRS (BASE)  "
            f"[v] View full resolved  [d] View full diff  [e] Edit  [s] Skip  [a] Accept all: "
            f"{Colors.NC}",
            end="",
        )
        decision = input().strip().lower()

        if decision == "v":
            print(f"\n{Colors.CYAN}--- Full Resolved File ({len(colored)} lines) ---{Colors.NC}")
            for line in colored:
                print(line)
            print(f"{Colors.CYAN}--- End ---{Colors.NC}")
        elif decision == "d":
            if full_diff is None:
                head_lines = (head_content or "").splitlines(keepends=True)
                base_lines = (base_content or "").splitlines(keepends=True)
                full_diff = list(difflib.unified_diff(base_lines, head_lines, fromfile="BASE", tofile="HEAD", lineterm=""))
            print(f"\n{Colors.CYAN}--- Full Diff ---{Colors.NC}")
            for line in full_diff:
                if line.startswith("+++") or line.startswith("---") or line.startswith("@@"):
                    print(f"{Colors.CYAN}{line}{Colors.NC}")
                elif line.startswith("+"):
                    print(f"{Colors.GREEN}{line}{Colors.NC}")
                elif line.startswith("-"):
                    print(f"{Colors.RED}{line}{Colors.NC}")
                else:
                    print(f"{Colors.GRAY}{line}{Colors.NC}")
            print(f"{Colors.CYAN}--- End ---{Colors.NC}")
        else:
            return decision


_http_client: Optional[httpx.AsyncClient] = None


def _get_http_client() -> httpx.AsyncClient:
    global _http_client
    if _http_client is None or _http_client.is_closed:
        _http_client = httpx.AsyncClient(
            timeout=180.0,
            limits=httpx.Limits(max_keepalive_connections=5, max_connections=10),
        )
    return _http_client


async def send_to_ollama(
    base_url: str,
    model: str,
    prompt: str,
    system: str = "",
    *,
    silent: bool = False,
    options: dict | None = None,
) -> str:
    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})

    # Smaller num_ctx than the model default keeps KV-cache allocation down — large defaults make
    # local Ollama feel "stuck" for tens of seconds before the first token. Override via OLLAMA_NUM_CTX.
    default_options = {
        "temperature": 0.1,
        "top_k": 20,
        "top_p": 0.5,
        "num_ctx": int(os.getenv("OLLAMA_NUM_CTX", "4096")),
        "num_predict": int(os.getenv("OLLAMA_NUM_PREDICT", "2000")),
    }
    if options:
        default_options.update(options)

    payload = {
        "model": model,
        "messages": messages,
        "stream": True,
        "options": default_options,
    }

    try:
        if not silent:
            print(f"{Colors.GRAY}Resolving...{Colors.NC}")
        tokens: list[str] = []
        client = _get_http_client()
        async with client.stream("POST", f"{base_url}/api/chat", json=payload) as response:
            response.raise_for_status()
            async for line in response.aiter_lines():
                if not line:
                    continue
                chunk = json.loads(line)
                token = chunk.get("message", {}).get("content", "")
                if token:
                    if not silent:
                        print(token, end="", flush=True)
                    tokens.append(token)
                if chunk.get("done"):
                    break
        if not silent:
            print()
        return "".join(tokens)
    except Exception as e:
        print(f"{Colors.RED}Error sending request to Ollama: {e}{Colors.NC}")
        sys.exit(1)


async def get_ollama_models(base_url: str) -> list:
    try:
        client = _get_http_client()
        response = await client.get(f"{base_url}/api/tags")
        response.raise_for_status()
        data = response.json()
        return [m["name"] for m in data.get("models", [])]
    except Exception:
        return []


def _build_file_context(file_path: str) -> str:
    """Return a natural-language description of what this file is and how to treat it when merging."""
    basename = os.path.basename(file_path)
    ext = os.path.splitext(file_path)[1].lower()

    # Lockfiles — machine-generated, never hand-merge
    if basename in ("package-lock.json", "yarn.lock", "pnpm-lock.yaml",
                    "poetry.lock", "Pipfile.lock", "Cargo.lock", "composer.lock",
                    "Gemfile.lock", "go.sum"):
        return (
            f"{basename} is a machine-generated lockfile. "
            "NEVER merge lockfile content manually — it will corrupt the dependency graph. "
            "Output ONLY the incoming (base_branch) version exactly as-is. "
            "The lockfile will be regenerated correctly after the manifest is merged."
        )

    # Dependency manifests
    if basename in ("package.json", "pyproject.toml", "requirements.txt",
                    "Cargo.toml", "go.mod", "composer.json", "Gemfile",
                    "build.gradle", "pom.xml", "*.csproj"):
        return (
            f"{basename} is a dependency manifest. "
            "Apply your knowledge of this format's schema and version resolution rules. "
            "Include dependencies and scripts from BOTH branches; resolve version conflicts "
            "by keeping the higher compatible version. Output must be valid and parseable."
        )

    # Git config files
    if basename == ".gitmodules" or basename == ".gitattributes":
        return (
            f"{basename} is a Git configuration file. "
            "Merge all entries from both branches. "
            "For submodule refs, prefer the incoming branch's pointer. "
            "Output must be a valid Git config format."
        )

    # CI / infrastructure as code
    if basename in ("Dockerfile", "docker-compose.yml", "docker-compose.yaml"):
        return (
            f"{basename} is a container configuration file. "
            "Apply your knowledge of Docker/Compose syntax. "
            "Merge environment variables, ports, volumes, and services from both branches. "
            "Output must be valid Dockerfile or Compose YAML."
        )
    if ext in (".tf", ".tfvars"):
        return (
            f"{basename} is a Terraform infrastructure file. "
            "Merge resource blocks and variable definitions from both branches. "
            "Preserve all resource arguments; never silently drop attributes. "
            "Output must be valid HCL."
        )

    # Generic dispatch by extension — tell Ollama the file type and trust its knowledge
    ext_descriptions = {
        ".ts": "TypeScript", ".tsx": "TypeScript React", ".js": "JavaScript",
        ".jsx": "JavaScript React", ".mjs": "ES Module JavaScript",
        ".py": "Python", ".rb": "Ruby", ".go": "Go", ".rs": "Rust",
        ".java": "Java", ".kt": "Kotlin", ".cs": "C#", ".cpp": "C++", ".c": "C",
        ".swift": "Swift", ".php": "PHP", ".scala": "Scala",
        ".yaml": "YAML", ".yml": "YAML",
        ".json": "JSON", ".jsonc": "JSON with Comments",
        ".toml": "TOML", ".ini": "INI config", ".env": "environment variables file",
        ".md": "Markdown", ".mdx": "MDX",
        ".sh": "shell script", ".bash": "Bash script", ".zsh": "Zsh script",
        ".sql": "SQL", ".graphql": "GraphQL schema", ".proto": "Protocol Buffers",
        ".xml": "XML", ".html": "HTML", ".css": "CSS", ".scss": "SCSS", ".sass": "Sass",
        ".prisma": "Prisma schema",
    }
    lang = ext_descriptions.get(ext)
    if lang:
        return (
            f"{basename} is a {lang} file. "
            f"Apply your expert knowledge of {lang} syntax, semantics, and best practices. "
            "Keep all imports, exports, type definitions, and functionality from both branches. "
            f"Output must be syntactically valid {lang} with no merge artifacts."
        )

    # Unknown — still tell Ollama the filename so it can infer
    return (
        f"{basename} is a {'configuration' if '.' not in basename or ext == '' else ext[1:].upper()} file. "
        "Apply your knowledge of this file format's structure and conventions. "
        "Keep all meaningful content from both branches. "
        "Output must be correctly formatted with no conflict markers."
    )


async def resolve_file_with_context(
    base_url: str,
    model: str,
    repo_path: str,
    file_path: str,
    head_branch: str,
    base_branch: str,
    explanation_mode: bool = False,
    silent: bool = False,
) -> dict:
    _LOCKFILES = frozenset({
        "package-lock.json", "yarn.lock", "pnpm-lock.yaml",
        "poetry.lock", "Pipfile.lock", "Cargo.lock", "composer.lock",
        "Gemfile.lock", "go.sum",
    })
    _MAX_CONTENT_LINES = 100

    # Parallelise all independent git calls — none of head/base_branch/diff depend on merge_base
    head_task        = asyncio.to_thread(get_branch_file_content, repo_path, head_branch, file_path)
    base_branch_task = asyncio.to_thread(get_branch_file_content, repo_path, base_branch, file_path)
    diff_task        = asyncio.to_thread(get_file_diff_hunks, repo_path, base_branch, head_branch, file_path)
    merge_base_task  = asyncio.to_thread(get_merge_base, repo_path, head_branch, base_branch)

    head_content, base_head_content, diff_hunks, merge_base = await asyncio.gather(
        head_task, base_branch_task, diff_task, merge_base_task
    )

    # base_content depends on merge_base — fetch now that we have it
    base_content = await asyncio.to_thread(
        get_branch_file_content, repo_path, merge_base, file_path
    ) if merge_base else ""

    # Short-circuit: lockfiles are machine-generated — always take incoming version, no LLM needed
    if os.path.basename(file_path) in _LOCKFILES:
        return {
            "content": base_head_content,
            "explanation": "Lockfile: took the incoming branch version unchanged (never hand-merge lockfiles).",
            "base": base_content,
            "head": head_content,
            "base_branch_version": base_head_content,
            "diff_hunks": diff_hunks,
        }

    def _maybe_trim(text: str, label: str) -> str:
        lines = text.splitlines()
        if len(lines) <= _MAX_CONTENT_LINES:
            return text
        # For large files, keep first and last 30 lines as structural anchors + rely on diff hunks
        head_lines = "\n".join(lines[:30])
        tail_lines = "\n".join(lines[-30:])
        return (
            f"{head_lines}\n\n"
            f"... [{len(lines) - 60} lines omitted — see CHANGES SUMMARY for the relevant diff hunks] ...\n\n"
            f"{tail_lines}"
        )

    file_context = _build_file_context(file_path)

    # Estimate how large the prompt will be and scale num_ctx accordingly
    prompt_content_len = sum(len(s) for s in (base_content, base_head_content, head_content, diff_hunks or "") if s)
    estimated_tokens = prompt_content_len // 4 + 800  # ~4 chars/token + system prompt overhead
    num_ctx = max(4096, min(int(estimated_tokens * 1.5), 16384))
    num_predict = max(512, min(int(max(len(head_content or ""), len(base_head_content or "")) // 3) + 256, 4096))

    system_prompt = f"""You are a senior systems engineer resolving a Git merge conflict.

FILE CONTEXT: {file_context}

BASE = common ancestor (how the file looked before both branches diverged).
HEAD = current branch (incoming changes being merged in).
INCOMING = target branch (where we're merging into).

RULES:
- Output ONLY the final merged file content — no commentary, no conflict markers, no markdown fences
- Use BASE to understand the original intent; do not just pick one side blindly
- Preserve all functionality, imports, error handling, and configuration from both branches
- Apply the file format's validity constraints (syntax, schema, structure)
- Never drop code unless it is genuinely superseded by the other branch
{"" if not explanation_mode else chr(10) + "After the file content, append <<<EXPLANATION>>> on its own line, then 2-3 sentences explaining the resolution."}"""

    user_prompt = f"""Resolve a merge conflict between two branches.

FILE: {file_path}

BRANCH INFO:
- Head branch (incoming changes): {head_branch}
- Base branch (target): {base_branch}

BASE VERSION (common ancestor - how the file started):
```
{_maybe_trim(base_content, "BASE") if base_content else "(file did not exist in base)"}
```

BASE_BRANCH VERSION ({base_branch}):
```
{_maybe_trim(base_head_content, "BASE_BRANCH") if base_head_content else "(file does not exist in this branch)"}
```

HEAD_BRANCH VERSION ({head_branch} - incoming changes):
```
{_maybe_trim(head_content, "HEAD") if head_content else "(file does not exist in this branch)"}
```

CHANGES SUMMARY (diff between base and head):
{diff_hunks[:4000] if diff_hunks else "(no hunks)"}

Resolve this conflict and output ONLY the final merged file content."""

    response = await send_to_ollama(
        base_url, model, user_prompt, system=system_prompt, silent=silent,
        options={"num_ctx": num_ctx, "num_predict": num_predict},
    )

    explanation = ""
    if explanation_mode and "<<<EXPLANATION>>>" in response:
        parts = response.split("<<<EXPLANATION>>>", 1)
        raw_content = parts[0].strip()
        explanation = parts[1].strip()
    else:
        raw_content = response.strip()

    cleaned = re.sub(r"^```[a-z]*\n?", "", raw_content)
    cleaned = re.sub(r"\n?```$", "", cleaned)

    return {
        "content": cleaned,
        "explanation": explanation,
        "base": base_content,
        "head": head_content,
        "base_branch_version": base_head_content,
        "diff_hunks": diff_hunks
    }


async def main():
    auto_resolve = "-y" in sys.argv or "--yes" in sys.argv
    explain_mode = "--explain" in sys.argv or "-e" in sys.argv
    ollama_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
    root_path = find_script_git_root()

    print(f"{Colors.CYAN}")
    print(f"╔{'═'*60}╗")
    print(f"║{' AI Git Merge Assistant (Deepiri) ':^60}║")
    print(f"║{'Compare branches, resolve conflicts, push changes ':^60}║")
    print(f"╚{'═'*60}╝{Colors.NC}")
    print()

    repos = find_git_repos(root_path)
    
    if not repos:
        print(f"{Colors.RED}No git repositories found.{Colors.NC}")
        sys.exit(1)

    print(f"{Colors.CYAN}Select repository:{Colors.NC}")
    for i, repo in enumerate(repos):
        print(f"  {Colors.BLUE}{i + 1}){Colors.NC} {repo['name']}")
    print(f"\n{Colors.GRAY}[Enter number, or 'q' to quit]{Colors.NC}")
    print(f"{Colors.CYAN}[1-{len(repos)}] or 'q': {Colors.NC}", end="")
    
    selection_input = input().strip().lower()
    if selection_input == "q":
        sys.exit(0)
    
    try:
        selection = int(selection_input) - 1
        if selection < 0 or selection >= len(repos):
            print(f"{Colors.RED}Invalid selection.{Colors.NC}")
            sys.exit(1)
    except ValueError:
        print(f"{Colors.RED}Invalid input.{Colors.NC}")
        sys.exit(1)
    
    repo = repos[selection]
    repo_path = repo["path"]
    repo_name = repo["name"]

    while True:
        current_branch = get_current_branch(repo_path)
        has_changes = has_uncommitted_changes(repo_path)
        conflict_files = get_conflict_files(repo_path)
        in_merge = os.path.isfile(os.path.join(repo_path, ".git", "MERGE_HEAD"))
        in_rebase = os.path.isdir(os.path.join(repo_path, ".git", "rebase-merge"))

        is_sub = repo.get("is_submodule", False)
        repo_label = f"{repo_name} (submodule)" if is_sub else repo_name
        print(f"\n{Colors.CYAN}╔{'─'*58}╗{Colors.NC}")
        print(f"{Colors.CYAN}║ Repository: {repo_label:<47}║{Colors.NC}")
        print(f"{Colors.CYAN}╠{'─'*58}╣{Colors.NC}")
        print(f"{Colors.CYAN}║ Branch: {Colors.BLUE}{current_branch or '(detached)':<50}{Colors.CYAN}║{Colors.NC}")
        if is_sub:
            parent_branch = get_current_branch(root_path)
            parent_label = f"Parent branch: {parent_branch}" if parent_branch else "Parent branch: unknown"
            print(f"{Colors.CYAN}║ {Colors.YELLOW}{parent_label:<57}{Colors.CYAN}║{Colors.NC}")
        if has_changes:
            print(f"{Colors.CYAN}║ {Colors.YELLOW}! Uncommitted changes{Colors.CYAN}{' ' * 37}║{Colors.NC}")
        if in_merge:
            print(f"{Colors.CYAN}║ {Colors.YELLOW}! Merge in progress{Colors.CYAN}{' ' * 38}║{Colors.NC}")
        if in_rebase:
            print(f"{Colors.CYAN}║ {Colors.YELLOW}! Rebase in progress{Colors.CYAN}{' ' * 38}║{Colors.NC}")
        if conflict_files:
            print(f"{Colors.CYAN}║ {Colors.RED}! {len(conflict_files)} conflict(s){Colors.CYAN}{' ' * 41}║{Colors.NC}")
        print(f"{Colors.CYAN}╚{'─'*58}╝{Colors.NC}")

        if conflict_files:
            print(f"\n{Colors.RED}Conflicts detected!{Colors.NC}")
            print(f"  {Colors.GRAY}Resolve existing merge/rebase conflicts first{Colors.NC}")
            print(f"\n{Colors.CYAN}[r] Resolve conflicts  [q] Quit: {Colors.NC}", end="")
            action = input().strip().lower()
            if action == "q":
                break
            elif action == "r":
                await resolve_existing_conflicts(repo_path, repo_name, ollama_url, root_path)
            continue

        if in_merge or in_rebase:
            print(f"\n{Colors.YELLOW}Merge/rebase in progress{Colors.NC}")
            print(f"{Colors.CYAN}[c] Continue  [a] Abort  [q] Quit: {Colors.NC}", end="")
            action = input().strip().lower()
            if action == "q":
                break
            elif action == "a":
                subprocess.run(["git", "merge", "--abort"], cwd=repo_path, capture_output=True)
                subprocess.run(["git", "rebase", "--abort"], cwd=repo_path, capture_output=True)
                print(f"{Colors.GREEN}Aborted{Colors.NC}")
            elif action == "c":
                subprocess.run(["git", "commit", "--no-edit"], cwd=repo_path, capture_output=True)
                subprocess.run(["git", "rebase", "--continue"], cwd=repo_path, capture_output=True)
            continue

        print(f"\n{Colors.CYAN}What would you like to do?{Colors.NC}")
        print()
        print(f"  {Colors.GREEN}[rc]  {Colors.NC} Resolve Conflicts   {Colors.GRAY}Show conflicting files between branches & resolve{Colors.NC}")
        print(f"  {Colors.BLUE}[cmp] {Colors.NC} Compare branches     {Colors.GRAY}Preview differences between two branches{Colors.NC}")
        print(f"  {Colors.GREEN}[mg]  {Colors.NC} Merge & Resolve      {Colors.GRAY}Merge another branch into current{Colors.NC}")
        print(f"  {Colors.GREEN}[rb]  {Colors.NC} Rebase               {Colors.GRAY}Rebase onto another branch{Colors.NC}")
        print(f"  {Colors.GREEN}[co]  {Colors.NC} Checkout branch     {Colors.GRAY}Switch to a different branch{Colors.NC}")
        print(f"  {Colors.BLUE}[ls]  {Colors.NC} List branches       {Colors.GRAY}Show all local & remote branches{Colors.NC}")
        print(f"  {Colors.GREEN}[f]   {Colors.NC} Fetch all           {Colors.GRAY}Update remote branch info{Colors.NC}")
        print(f"  {Colors.MAGENTA}[push]{Colors.NC} Push changes        {Colors.GRAY}Push current branch to remote{Colors.NC}")
        print(f"  {Colors.YELLOW}[q]   {Colors.NC} Quit")
        print()
        print(f"{Colors.GRAY}Type 'hint <topic>' for help (merge, rebase, compare, etc.){Colors.NC}")
        print(f"\n{Colors.CYAN}Choice: {Colors.NC}", end="")
        
        action = input().strip().lower()

        if action == "q":
            break
        elif action.startswith("hint "):
            hint_type = action.split(" ", 1)[1] if " " in action else ""
            if hint_type == "merge":
                print(Hints.MERGE)
            elif hint_type == "rebase":
                print(Hints.REBASE)
            elif hint_type == "compare":
                print(Hints.COMPARE)
            elif hint_type == "resolve":
                print(Hints.RESOLVE)
            elif hint_type == "accept" or hint_type == "acceptall":
                print(Hints.ACCEPT_ALL)
            elif hint_type == "review":
                print(Hints.REVIEW)
            elif hint_type == "push":
                print(Hints.PUSH)
            else:
                print(f"{Colors.GRAY}Available hints: merge, rebase, compare, resolve, accept, review, push{Colors.NC}")
            continue
        elif action == "ls":
            print(f"\n{Colors.CYAN}Local branches:{Colors.NC}")
            local = get_local_branches(repo_path)
            if current_branch:
                for b in local:
                    marker = " *" if b == current_branch else ""
                    print(f"  {b}{Colors.GREEN}{marker}{Colors.NC}")
            else:
                print(f"  {Colors.YELLOW}(HEAD detached){Colors.NC}")
                for b in local:
                    print(f"  {b}")
            
            remote = get_remote_branches(repo_path)
            if remote:
                print(f"\n{Colors.CYAN}Remote branches:{Colors.NC}")
                for b in remote[:30]:
                    print(f"  {Colors.GRAY}{b}{Colors.NC}")
                if len(remote) > 30:
                    print(f"  {Colors.GRAY}... and {len(remote) - 30} more{Colors.NC}")
            print()
            continue
        elif action == "f":
            print(f"{Colors.CYAN}Fetching all remotes...{Colors.NC}")
            if fetch_all(repo_path):
                print(f"{Colors.GREEN}Fetch complete{Colors.NC}")
            else:
                print(f"{Colors.RED}Fetch failed{Colors.NC}")
            continue
        elif action == "co":
            print(f"\n{Colors.CYAN}Available branches:{Colors.NC}")
            local = get_local_branches(repo_path)
            remote = get_remote_branches(repo_path)
            
            for b in local:
                marker = " *" if b == current_branch else ""
                print(f"  {b}{Colors.GREEN}{marker}{Colors.NC}")
            
            if remote:
                print(f"\n{Colors.GRAY}Remote (use 'origin/X' to checkout):{Colors.NC}")
                for b in remote[:20]:
                    print(f"  {Colors.GRAY}{b}{Colors.NC}")
            
            print(f"\n{Colors.CYAN}Branch name: {Colors.NC}", end="")
            branch_input = input().strip()
            if branch_input:
                if checkout_branch(repo_path, branch_input):
                    print(f"{Colors.GREEN}Switched to {branch_input}{Colors.NC}")
                else:
                    print(f"{Colors.RED}Failed to checkout{Colors.NC}")
            continue
        elif action == "push":
            if not current_branch:
                print(f"{Colors.RED}Cannot push - HEAD is detached{Colors.NC}")
                continue
            
            print(f"\n{Colors.CYAN}Pushing {current_branch} to remote...{Colors.NC}")
            result = subprocess.run(
                ["git", "push", "-u", "origin", current_branch],
                cwd=repo_path,
                capture_output=True,
                text=True,
            )
            if result.returncode == 0:
                print(f"{Colors.GREEN}Pushed successfully!{Colors.NC}")
            else:
                print(f"{Colors.RED}Push failed: {result.stderr}{Colors.NC}")
            continue
        elif action == "cmp":
            print(Hints.COMPARE)
            print(f"{Colors.CYAN}HEAD branch (incoming changes){Colors.NC}")
            print(f"{Colors.GRAY}  [Enter for current branch: {current_branch}]{Colors.NC}")
            print(f"{Colors.CYAN}> {Colors.NC}", end="")
            head = input().strip()
            if not head:
                head = current_branch
            print(f"{Colors.CYAN}BASE branch (target){Colors.NC}")
            print(f"{Colors.GRAY}  [e.g., origin/main, origin/dev]{Colors.NC}")
            print(f"{Colors.CYAN}> {Colors.NC}", end="")
            base = input().strip()
            
            if not base:
                print(f"{Colors.YELLOW}Base branch required{Colors.NC}")
                continue
            
            print(f"\n{Colors.CYAN}Fetching latest remote info...{Colors.NC}")
            fetch_all(repo_path)
            
            print(f"\n{Colors.CYAN}Comparing {Colors.BLUE}{head}{Colors.CYAN} vs {Colors.GREEN}{base}{Colors.CYAN}...{Colors.NC}")
            
            diff_result = get_file_diff_between_branches(repo_path, base, head)
            if diff_result["success"]:
                print(f"\n{Colors.CYAN}Files that differ ({diff_result['count']}):{Colors.NC}")
                if diff_result["files"]:
                    for f in diff_result["files"][:20]:
                        print(f"  {Colors.YELLOW}~{Colors.NC} {f}")
                    if len(diff_result["files"]) > 20:
                        print(f"  {Colors.GRAY}... and {len(diff_result['files']) - 20} more{Colors.NC}")
                else:
                    print(f"  {Colors.GREEN}No differences at branch tips{Colors.NC}")
                
                print(f"\n{Colors.CYAN}Conflict prediction (since branches diverged):{Colors.NC}")
                prediction = predict_conflicts(repo_path, head, base)
                if prediction["would_conflict"]:
                    print(f"  {Colors.YELLOW}{prediction['message']}{Colors.NC}")
                    print(f"  {Colors.GRAY}Files with potential conflicts:{Colors.NC}")
                    for f in prediction["files"][:10]:
                        print(f"    {Colors.RED}!{Colors.NC} {f}")
                else:
                    print(f"  {Colors.GREEN}{prediction['message']}{Colors.NC}")
            else:
                print(f"{Colors.RED}Error: {diff_result.get('error', 'Unknown error')}{Colors.NC}")
            continue
        elif action == "mg" or action == "merge":
            print(Hints.MERGE)
            await handle_merge_flow(repo_path, repo_name, ollama_url, root_path)
            continue
        elif action == "rc" or action == "resolveconflicts":
            await handle_resolve_conflicts_between_branches(repo_path, repo_name, ollama_url, root_path)
            continue
        elif action == "rb" or action == "rebase":
            print(Hints.REBASE)
            print(f"{Colors.CYAN}Rebase current branch onto (enter branch name):{Colors.NC}", end="")
            target = input().strip()
            if not target:
                continue
            
            if has_changes:
                print(f"{Colors.YELLOW}Stashing changes...{Colors.NC}")
                subprocess.run(["git", "stash"], cwd=repo_path, capture_output=True)
            
            result = subprocess.run(
                ["git", "rebase", target],
                cwd=repo_path,
                capture_output=True,
                text=True,
            )
            
            if result.returncode == 0:
                print(f"{Colors.GREEN}Rebase complete!{Colors.NC}")
            else:
                conflicts = get_conflict_files(repo_path)
                if conflicts:
                    print(f"{Colors.YELLOW}Conflicts detected. Use 'mg' to resolve.{Colors.NC}")
                else:
                    print(f"{Colors.RED}Rebase failed{Colors.NC}")
            continue
        else:
            print(f"{Colors.YELLOW}Unknown command. Try: cmp, mg, rc, rb, co, ls, f, push{Colors.NC}")


async def handle_resolve_conflicts_between_branches(repo_path: str, repo_name: str, ollama_url: str, root_path: str):
    current_branch = get_current_branch(repo_path)
    
    print(f"\n{Colors.CYAN}Resolve Conflicts Between Branches{Colors.NC}")
    print(f"{Colors.GRAY}Your current branch: {Colors.BLUE}{current_branch}{Colors.NC}")
    print()
    print(Hints.RESOLVE)
    print(f"{Colors.CYAN}HEAD branch (incoming changes - has new code){Colors.NC}")
    print(f"{Colors.GRAY}  [Enter for current branch: {current_branch}]{Colors.NC}")
    head_branch = input(f"{Colors.CYAN}> {Colors.NC}").strip()
    if not head_branch:
        head_branch = current_branch

    def get_sha(ref):
        r = subprocess.run(["git", "rev-parse", "--short", ref], cwd=repo_path, capture_output=True, text=True)
        return r.stdout.strip() if r.returncode == 0 else "unknown"

    # BASE branch input with retry — bad names re-prompt instead of dropping to the main menu
    base_branch = None
    preview_conflicts = None
    while True:
        if base_branch is None:
            print(f"\n{Colors.CYAN}BASE branch (target - typically main/develop){Colors.NC}")
            print(f"{Colors.GRAY}  [e.g., origin/dev, origin/main  |  blank to cancel]{Colors.NC}")
            val = input(f"{Colors.CYAN}> {Colors.NC}").strip()
            if not val:
                return
            base_branch = val

        # Fetch both branches specifically
        print(f"\n{Colors.CYAN}Fetching latest remote refs...{Colors.NC}")
        for ref in [head_branch, base_branch]:
            branch_name = ref.replace("origin/", "")
            r = subprocess.run(["git", "fetch", "origin", branch_name], cwd=repo_path, capture_output=True, text=True)
            if r.returncode == 0:
                print(f"  {Colors.GREEN}fetched{Colors.NC} origin/{branch_name}")
            else:
                print(f"  {Colors.YELLOW}could not fetch origin/{branch_name} — using local cache{Colors.NC}")

        resolved_head = f"origin/{head_branch.replace('origin/', '')}"
        resolved_base = base_branch if base_branch.startswith("origin/") else f"origin/{base_branch}"
        print(f"  {Colors.BLUE}{resolved_head}{Colors.NC} @ {Colors.GRAY}{get_sha(resolved_head)}{Colors.NC}")
        print(f"  {Colors.GREEN}{base_branch}{Colors.NC} @ {Colors.GRAY}{get_sha(resolved_base)}{Colors.NC}")

        print(f"\n{Colors.CYAN}Checking for conflicts between {Colors.BLUE}{head_branch}{Colors.CYAN} and {Colors.GREEN}{base_branch}{Colors.CYAN}...{Colors.NC}")
        preview_conflicts = get_conflicting_files_between_branches(repo_path, head_branch, base_branch)

        if preview_conflicts is None:
            print(f"{Colors.RED}Branch '{base_branch}' not found. Try again (blank to cancel):{Colors.NC}")
            base_branch = None
            continue

        break

    true_conflicts    = preview_conflicts["true_conflicts"]
    deletion_warnings = preview_conflicts.get("deletion_warnings", [])

    if not true_conflicts and not deletion_warnings:
        print(f"{Colors.GREEN}No conflicts - these branches merge cleanly!{Colors.NC}")
        return

    if true_conflicts:
        print(f"\n{Colors.RED}{len(true_conflicts)} file(s) need conflict resolution:{Colors.NC}")
        for f in true_conflicts:
            print(f"  {Colors.RED}x{Colors.NC} {f}")
    else:
        print(f"\n{Colors.GREEN}No hard conflicts - git can auto-merge everything.{Colors.NC}")

    if deletion_warnings:
        print(f"\n{Colors.YELLOW}{len(deletion_warnings)} file(s) deleted in {head_branch} will stay deleted after merge  "
              f"[d to inspect]{Colors.NC}")

    print(f"\n{Colors.CYAN}This will merge {base_branch} into {head_branch} with AI conflict resolution{Colors.NC}")

    prompt = f"{Colors.CYAN}[y] Proceed  [n] Cancel"
    if deletion_warnings:
        prompt += "  [d] Inspect deletions"
    prompt += f": {Colors.NC}"

    while True:
        print(prompt, end="")
        choice = input().strip().lower()
        if choice == "d" and deletion_warnings:
            print(f"\n{Colors.YELLOW}Files that will be deleted from {base_branch}:{Colors.NC}")
            for f in deletion_warnings:
                print(f"  {Colors.YELLOW}-{Colors.NC} {f}")
            print()
        elif choice == "y":
            break
        else:
            print("Cancelled")
            return
    has_changes = has_uncommitted_changes(repo_path)
    if has_changes:
        print(f"{Colors.YELLOW}Stashing uncommitted changes...{Colors.NC}")
        subprocess.run(["git", "stash"], cwd=repo_path, capture_output=True)

    # Checkout the head branch if we're not already on it
    if head_branch != current_branch:
        print(f"{Colors.CYAN}Checking out {head_branch}...{Colors.NC}")
        co = subprocess.run(
            ["git", "checkout", head_branch],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )
        if co.returncode != 0:
            print(f"{Colors.RED}Failed to checkout {head_branch}: {co.stderr.strip()}{Colors.NC}")
            if has_changes:
                subprocess.run(["git", "stash", "pop"], cwd=repo_path, capture_output=True)
            return

    print(f"{Colors.CYAN}Starting merge of {base_branch} into {head_branch}...{Colors.NC}")
    subprocess.run(
        ["git", "merge", "--no-commit", "--no-ff", base_branch],
        cwd=repo_path,
        capture_output=True,
        text=True,
    )
    conflict_files = get_conflict_files(repo_path)
    if not conflict_files:
        subprocess.run(["git", "commit", "--no-edit"], cwd=repo_path, capture_output=True)
        if has_changes:
            subprocess.run(["git", "stash", "pop"], cwd=repo_path, capture_output=True)
        print(f"{Colors.GREEN}Merged cleanly — no conflicts!{Colors.NC}")
        return
    if not is_ollama_running(ollama_url):
        print(f"\n{Colors.YELLOW}Ollama is not running.{Colors.NC}")
        print(f"{Colors.CYAN}[s] Start  [m] Pull models  [q] Quit: {Colors.NC}", end="")
        response = input().strip().lower()
        if response == "s":
            if not start_ollama(root_path, ollama_url):
                print(f"{Colors.RED}Could not start Ollama{Colors.NC}")
                if has_changes:
                    subprocess.run(["git", "stash", "pop"], cwd=repo_path, capture_output=True)
                return
        elif response == "q":
            if has_changes:
                subprocess.run(["git", "stash", "pop"], cwd=repo_path, capture_output=True)
            return
        else:
            if has_changes:
                subprocess.run(["git", "stash", "pop"], cwd=repo_path, capture_output=True)
            return

    async with Spinner(f"Connecting to Ollama..."):
        models = await get_ollama_models(ollama_url)
    
    if not models:
        print(f"{Colors.RED}No models available in Ollama{Colors.NC}")
        if has_changes:
            subprocess.run(["git", "stash", "pop"], cwd=repo_path, capture_output=True)
        return

    model = models[0]
    if len(models) > 1:
        print(f"\n{Colors.CYAN}Select model:{Colors.NC}")
        for i, m in enumerate(models):
            print(f"  {i + 1}) {m}")
        print(f"{Colors.GRAY}[1]: {Colors.NC}", end="")
        sel = input().strip()
        if sel.isdigit() and 1 <= int(sel) <= len(models):
            model = models[int(sel) - 1]

    print(f"\n{Colors.CYAN}Resolution mode:{Colors.NC}")
    print(f"  {Colors.GREEN}[a] Accept All     {Colors.GRAY}AI resolves everything automatically (fast){Colors.NC}")
    print(f"  {Colors.BLUE}[r] Review Each    {Colors.GRAY}AI explains each decision (educational){Colors.NC}")
    print(f"\n{Colors.GRAY}[a/r]: {Colors.NC}", end="")
    mode = input().strip().lower()
    
    review_mode = mode == "r"
    
    if review_mode:
        print(Hints.REVIEW)
    else:
        print(Hints.ACCEPT_ALL)
    
    print(f"\n{Colors.CYAN}Processing {len(conflict_files)} file(s)...{Colors.NC}")

    resolved = 0
    skipped = 0

    for i, file_path in enumerate(conflict_files):
        full_path = os.path.join(repo_path, file_path)

        print(f"\n{Colors.CYAN}[{i+1}/{len(conflict_files)}] {file_path}{Colors.NC}")

        # Handle submodule pointer conflicts specially
        if is_submodule_path(repo_path, file_path):
            print(f"  {Colors.YELLOW}Submodule pointer conflict — picking latest commit...{Colors.NC}")
            if resolve_submodule_conflict(repo_path, file_path):
                print(f"  {Colors.GREEN}Resolved submodule pointer: {file_path}{Colors.NC}")
                resolved += 1
            else:
                print(f"  {Colors.RED}Could not auto-resolve submodule pointer: {file_path}{Colors.NC}")
                skipped += 1
            continue

        result = await resolve_file_with_context(
            base_url=ollama_url,
            model=model,
            repo_path=repo_path,
            file_path=file_path,
            head_branch=head_branch,
            base_branch=base_branch,
            explanation_mode=review_mode,
            silent=not review_mode,
        )

        if review_mode:
            decision = review_and_decide(result)

            if decision == "a":
                review_mode = False
                decision = "y"
            elif decision == "s":
                skipped += 1
                continue
            elif decision == "o":
                # Keep ours (HEAD branch version)
                result["content"] = result.get("head", "")
                print(f"  {Colors.BLUE}Using HEAD (ours): {file_path}{Colors.NC}")
                decision = "y"
            elif decision == "t":
                # Keep theirs (BASE branch version)
                result["content"] = result.get("base_branch_version", "")
                print(f"  {Colors.GREEN}Using BASE (theirs): {file_path}{Colors.NC}")
                decision = "y"
            elif decision == "e":
                editor = os.getenv("EDITOR", "vim")
                temp = full_path + ".review_tmp"
                with open(temp, "w") as f:
                    f.write(result["content"])
                subprocess.run([editor, temp])
                with open(temp, "r") as f:
                    result["content"] = f.read()
                os.remove(temp)
                decision = "y"
        else:
            print(f"  {Colors.GREEN}Resolved: {file_path}{Colors.NC}")
            decision = "y"

        if decision == "y":
            # Check resolved content doesn't still have conflict markers
            content = result["content"]
            if any(m in content for m in ("<<<<<<< ", "======= ", ">>>>>>> ")):
                print(f"  {Colors.RED}AI left conflict markers in output — skipping (use [e] to fix manually){Colors.NC}")
                skipped += 1
                continue
            with open(full_path, "w") as f:
                f.write(content)
            subprocess.run(["git", "add", file_path], cwd=repo_path, capture_output=True)
            resolved += 1

    print(f"\n{Colors.CYAN}{'='*60}{Colors.NC}")
    print(f"{Colors.GREEN}Resolution complete!{Colors.NC}")
    print(f"  Resolved: {resolved}")
    if skipped:
        print(f"  Skipped: {skipped}")
    print(f"{Colors.CYAN}{'='*60}{Colors.NC}")

    # Pop stash before committing so stash-pop conflicts surface cleanly
    if has_changes:
        pop = subprocess.run(["git", "stash", "pop"], cwd=repo_path, capture_output=True, text=True)
        if pop.returncode != 0:
            stash_conflicts = get_conflict_files(repo_path)
            if stash_conflicts:
                print(f"\n{Colors.YELLOW}Stash pop created {len(stash_conflicts)} conflict(s) — resolve before committing:{Colors.NC}")
                for f in stash_conflicts:
                    print(f"  {Colors.YELLOW}!{Colors.NC} {f}")
                return

    # Final check — refuse to commit if any UU files remain
    still_conflicted = get_conflict_files(repo_path)
    if still_conflicted:
        print(f"\n{Colors.RED}{len(still_conflicted)} file(s) still have conflicts — commit blocked:{Colors.NC}")
        for f in still_conflicted:
            print(f"  {Colors.RED}x{Colors.NC} {f}")
        return

    if resolved > 0:
        print(f"\n{Colors.CYAN}[c] Commit changes  [p] Commit & push  [q] Just finish: {Colors.NC}", end="")
        action = input().strip().lower()

        if action == "c" or action == "p":
            result = subprocess.run(
                ["git", "commit", "--no-edit"],
                cwd=repo_path,
                capture_output=True,
                text=True,
            )
            if result.returncode == 0:
                print(f"{Colors.GREEN}Committed!{Colors.NC}")

                if action == "p":
                    result = subprocess.run(
                        ["git", "push", "origin", head_branch],
                        cwd=repo_path,
                        capture_output=True,
                        text=True,
                    )
                    if result.returncode == 0:
                        print(f"{Colors.GREEN}Pushed to origin/{head_branch}{Colors.NC}")
                    else:
                        print(f"{Colors.RED}Push failed: {result.stderr}{Colors.NC}")
            else:
                print(f"{Colors.RED}Commit failed: {result.stderr}{Colors.NC}")


async def handle_merge_flow(repo_path: str, repo_name: str, ollama_url: str, root_path: str):
    current_branch = get_current_branch(repo_path)
    
    print(f"\n{Colors.CYAN}Merge Flow{Colors.NC}")
    print(f"{Colors.GRAY}Current branch: {Colors.BLUE}{current_branch}{Colors.NC}")
    print()
    print(f"{Colors.CYAN}Enter branch to merge INTO {current_branch}:{Colors.NC}", end="")
    incoming_branch = input().strip()
    
    if not incoming_branch:
        return
    
    if incoming_branch == current_branch:
        print(f"{Colors.RED}Cannot merge branch into itself{Colors.NC}")
        return

    has_changes = has_uncommitted_changes(repo_path)
    if has_changes:
        print(f"{Colors.YELLOW}Stashing uncommitted changes...{Colors.NC}")
        subprocess.run(["git", "stash"], cwd=repo_path, capture_output=True)
    
    print(f"\n{Colors.CYAN}Merging {incoming_branch} into {current_branch}...{Colors.NC}")
    result = subprocess.run(
        ["git", "merge", incoming_branch],
        cwd=repo_path,
        capture_output=True,
        text=True,
    )
    
    conflicts = get_conflict_files(repo_path)
    
    if conflicts:
        print(f"\n{Colors.YELLOW}{len(conflicts)} conflict(s) detected:{Colors.NC}")
        for f in conflicts[:10]:
            print(f"  {Colors.RED}!{Colors.NC} {f}")
        if len(conflicts) > 10:
            print(f"  {Colors.GRAY}... and {len(conflicts) - 10} more{Colors.NC}")
        
        print(f"\n{Colors.CYAN}Resolve conflicts now? [y/n]: {Colors.NC}", end="")
        if input().strip().lower() == "y":
            await resolve_merge_conflicts(
                repo_path, repo_name, ollama_url, root_path,
                current_branch, incoming_branch
            )
        else:
            print(f"\n{Colors.YELLOW}Conflicts left unresolved.{Colors.NC}")
            print(f"Run this tool again or use 'git merge --abort' to cancel.")
    else:
        print(f"{Colors.GREEN}Merge successful - no conflicts!{Colors.NC}")
        
        print(f"\n{Colors.CYAN}[push] Push to remote  [skip] Just finish: {Colors.NC}", end="")
        if input().strip().lower() == "push":
            result = subprocess.run(
                ["git", "push", "origin", current_branch],
                cwd=repo_path,
                capture_output=True,
                text=True,
            )
            if result.returncode == 0:
                print(f"{Colors.GREEN}Pushed to origin/{current_branch}{Colors.NC}")
            else:
                print(f"{Colors.RED}Push failed{Colors.NC}")
    
    if has_changes:
        pop = subprocess.run(["git", "stash", "pop"], cwd=repo_path, capture_output=True, text=True)
        if pop.returncode != 0:
            stash_conflicts = get_conflict_files(repo_path)
            if stash_conflicts:
                print(f"\n{Colors.YELLOW}Stash pop created {len(stash_conflicts)} conflict(s) in files you had open:{Colors.NC}")
                for f in stash_conflicts:
                    print(f"  {Colors.YELLOW}!{Colors.NC} {f}")
                print(f"{Colors.GRAY}Tip: use [r] Resolve conflicts from the main menu to fix these.{Colors.NC}")


async def resolve_merge_conflicts(
    repo_path: str, repo_name: str, ollama_url: str, root_path: str,
    current_branch: str = None, incoming_branch: str = None
):
    current_branch = current_branch or get_current_branch(repo_path)

    in_merge = os.path.isfile(os.path.join(repo_path, ".git", "MERGE_HEAD"))
    if in_merge and not incoming_branch:
        with open(os.path.join(repo_path, ".git", "MERGE_HEAD"), "r") as f:
            incoming_branch = f.read().strip()
    elif not incoming_branch:
        # No active merge (e.g. stash pop left conflicts after merge was committed).
        # Use ORIG_HEAD as the "other side" reference, falling back to HEAD~1.
        orig = subprocess.run(
            ["git", "rev-parse", "--verify", "ORIG_HEAD"],
            cwd=repo_path, capture_output=True, text=True
        )
        incoming_branch = orig.stdout.strip() if orig.returncode == 0 else "HEAD~1"
    
    print(Hints.RESOLVE)
    
    conflict_files = get_conflict_files(repo_path)
    if not conflict_files:
        print(f"{Colors.GREEN}No conflicts!{Colors.NC}")
        return
    
    if not is_ollama_running(ollama_url):
        print(f"\n{Colors.YELLOW}Ollama is not running.{Colors.NC}")
        print(f"{Colors.CYAN}[s] Start  [m] Pull models  [q] Quit: {Colors.NC}", end="")
        response = input().strip().lower()
        if response == "s":
            if not start_ollama(root_path, ollama_url):
                print(f"{Colors.RED}Could not start Ollama{Colors.NC}")
                return
        elif response == "m":
            check_script = find_check_ollama_script(root_path)
            if check_script:
                subprocess.run([check_script], cwd=root_path)
            return
        elif response == "q":
            return
        else:
            return

    async with Spinner(f"Connecting to Ollama..."):
        models = await get_ollama_models(ollama_url)
    
    if not models:
        print(f"{Colors.RED}No models available in Ollama{Colors.NC}")
        return

    model = models[0]
    if len(models) > 1:
        print(f"\n{Colors.CYAN}Select model:{Colors.NC}")
        for i, m in enumerate(models):
            print(f"  {i + 1}) {m}")
        print(f"{Colors.GRAY}[1]: {Colors.NC}", end="")
        sel = input().strip()
        if sel.isdigit() and 1 <= int(sel) <= len(models):
            model = models[int(sel) - 1]

    print(f"\n{Colors.CYAN}Resolution mode:{Colors.NC}")
    print(f"  {Colors.GREEN}[a] Accept All     {Colors.GRAY}AI resolves everything automatically (fast){Colors.NC}")
    print(f"  {Colors.BLUE}[r] Review Each    {Colors.GRAY}AI explains each decision (educational){Colors.NC}")
    print(f"\n{Colors.GRAY}[a/r]: {Colors.NC}", end="")
    mode = input().strip().lower()
    
    review_mode = mode == "r"
    
    if review_mode:
        print(Hints.REVIEW)
    else:
        print(Hints.ACCEPT_ALL)
    
    conflict_files = get_conflict_files(repo_path)
    
    if review_mode:
        print(f"\n{Colors.CYAN}Reviewing {len(conflict_files)} file(s)...{Colors.NC}")
    else:
        print(f"\n{Colors.CYAN}Resolving {len(conflict_files)} file(s)...{Colors.NC}")
    
    resolved = 0
    skipped = 0
    
    for i, file_path in enumerate(conflict_files):
        full_path = os.path.join(repo_path, file_path)

        print(f"\n{Colors.CYAN}[{i+1}/{len(conflict_files)}] Processing: {file_path}{Colors.NC}")

        # Handle submodule pointer conflicts specially
        if is_submodule_path(repo_path, file_path):
            print(f"  {Colors.YELLOW}Submodule pointer conflict — picking latest commit...{Colors.NC}")
            if resolve_submodule_conflict(repo_path, file_path):
                print(f"  {Colors.GREEN}Resolved submodule pointer: {file_path}{Colors.NC}")
                subprocess.run(["git", "add", file_path], cwd=repo_path, capture_output=True)
                resolved += 1
            else:
                print(f"  {Colors.RED}Could not auto-resolve submodule pointer: {file_path}{Colors.NC}")
                skipped += 1
            continue

        result = await resolve_file_with_context(
            base_url=ollama_url,
            model=model,
            repo_path=repo_path,
            file_path=file_path,
            head_branch=incoming_branch,
            base_branch=current_branch,
            explanation_mode=review_mode,
            silent=not review_mode,
        )

        if review_mode:
            decision = review_and_decide(result)

            if decision == "a":
                review_mode = False
                decision = "y"
            elif decision == "s":
                skipped += 1
                continue
            elif decision == "e":
                editor = os.getenv("EDITOR", "vim")
                temp = file_path + ".tmp"
                with open(temp, "w") as f:
                    f.write(result["content"])
                subprocess.run([editor, temp])
                with open(temp, "r") as f:
                    result["content"] = f.read()
                os.remove(temp)
                decision = "y"
        else:
            print(f"  {Colors.GREEN}Resolved: {file_path}{Colors.NC}")
            decision = "y"

        if decision == "y":
            with open(full_path, "w") as f:
                f.write(result["content"])
            subprocess.run(["git", "add", file_path], cwd=repo_path, capture_output=True)
            resolved += 1
    
    print(f"\n{Colors.CYAN}{'='*60}{Colors.NC}")
    print(f"{Colors.GREEN}Resolution complete!{Colors.NC}")
    print(f"  Resolved: {resolved}")
    if skipped:
        print(f"  Skipped: {skipped}")
    print(f"{Colors.CYAN}{'='*60}{Colors.NC}")
    
    if resolved > 0:
        print(f"\n{Colors.CYAN}[c] Commit merge  [p] Commit & push  [q] Just finish: {Colors.NC}", end="")
        action = input().strip().lower()
        
        if action == "c" or action == "p":
            result = subprocess.run(
                ["git", "commit", "-m", f"Merge branch '{incoming_branch}' into {current_branch}"],
                cwd=repo_path,
                capture_output=True,
                text=True,
            )
            if result.returncode == 0:
                print(f"{Colors.GREEN}Merge committed!{Colors.NC}")
                
                if action == "p":
                    result = subprocess.run(
                        ["git", "push", "-u", "origin", current_branch],
                        cwd=repo_path,
                        capture_output=True,
                        text=True,
                    )
                    if result.returncode == 0:
                        print(f"{Colors.GREEN}Pushed to origin/{current_branch}{Colors.NC}")
                    else:
                        print(f"{Colors.RED}Push failed: {result.stderr}{Colors.NC}")
            else:
                print(f"{Colors.RED}Commit failed: {result.stderr}{Colors.NC}")


async def resolve_existing_conflicts(repo_path: str, repo_name: str, ollama_url: str, root_path: str):
    await resolve_merge_conflicts(repo_path, repo_name, ollama_url, root_path)


if __name__ == "__main__":
    asyncio.run(main())
