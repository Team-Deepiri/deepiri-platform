#!/usr/bin/env python3
"""
Branch-merge PR Creator for Deepiri (can be Dev-to-Main or Main-to-Dev)
Creates PRs between two branches across the repos via GitHub CLI.
No local clones required — operates entirely through the GitHub API.

Usage:
    python dev-to-main-pr.py                     # default: dev → main
    python dev-to-main-pr.py --draft             # create PRs as drafts
    python dev-to-main-pr.py --dry-run           # preview only, no PRs created
    python dev-to-main-pr.py --backwards         # reverse: main → dev
"""
import json
import os
import subprocess
import sys
from typing import Optional


class Colors:
    GREEN = "\033[0;32m"
    RED = "\033[0;31m"
    BOLD = "\033[1m"
    YELLOW = "\033[1;33m"
    BLUE = "\033[0;34m"
    CYAN = "\033[0;36m"
    GRAY = "\033[0;90m"
    NC = "\033[0m"


GITHUB_ORG = "Team-Deepiri"
HEAD_BRANCH = "dev"
BASE_BRANCH = "main"


# ---------------------------------------------------------------------------
# GitHub helpers (all via gh CLI, no local git needed)
# ---------------------------------------------------------------------------

def gh(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["gh"] + list(args), capture_output=True, text=True)


def gh_api(path: str) -> tuple[int, any]:
    result = subprocess.run(["gh", "api", path], capture_output=True, text=True)
    try:
        data = json.loads(result.stdout) if result.stdout.strip() else {}
    except json.JSONDecodeError:
        data = {}
    return result.returncode, data

def get_org_repos() -> list[str]:
    result = gh(
        "api",
        f"orgs/{GITHUB_ORG}/repos",
        "--paginate",
        "--jq", '.[] | select(.archived==false and .fork==false) | .name'
    )
    if result.returncode != 0:
        print(f"{Colors.RED}Failed to fetch repos: {result.stderr}{Colors.NC}")
        return []
    return [r for r in result.stdout.strip().split("\n") if r]

def check_gh_auth() -> bool:
    return gh("auth", "status").returncode == 0


def repo_slug(repo_name: str) -> str:
    return f"{GITHUB_ORG}/{repo_name}"


def branch_exists(repo_name: str, branch: str) -> bool:
    code, data = gh_api(f"repos/{repo_slug(repo_name)}/branches/{branch}")
    return code == 0 and isinstance(data, dict) and "name" in data


def get_compare(repo_name: str, base: str, head: str) -> dict:
    code, data = gh_api(f"repos/{repo_slug(repo_name)}/compare/{base}...{head}")
    if code != 0 or not isinstance(data, dict):
        return {}
    return data


def pr_exists(repo_name: str, head_branch: str, base_branch: str) -> Optional[str]:
    result = gh(
        "pr", "list",
        "--repo", repo_slug(repo_name),
        "--head", head_branch,
        "--base", base_branch,
        "--json", "url",
    )
    if result.returncode == 0 and result.stdout.strip():
        try:
            prs = json.loads(result.stdout)
            if prs:
                return prs[0].get("url", "")
        except Exception:
            pass
    return None


def create_pr(repo_name: str, title: str, body: str, draft: bool = False) -> tuple[bool, str]:
    args = [
        "pr", "create",
        "--repo", repo_slug(repo_name),
        "--head", HEAD_BRANCH,
        "--base", BASE_BRANCH,
        "--title", title,
        "--body", body,
    ]
    if draft:
        args.append("--draft")
    result = gh(*args)
    if result.returncode == 0:
        return True, result.stdout.strip()
    return False, (result.stderr or result.stdout).strip()


# ---------------------------------------------------------------------------
# Display helpers
# ---------------------------------------------------------------------------

def print_banner():
    # Reflect the active HEAD -> BASE direction
    direction = f"{HEAD_BRANCH} → {BASE_BRANCH}"
    subtitle = f"24 repos · {direction} · GitHub API"
    print(f"{Colors.CYAN}")
    print(f"╔{'═'*60}╗")
    print(f"║{direction:^60}║")
    print(f"║{subtitle:^60}║")
    print(f"╚{'═'*60}╝{Colors.NC}")
    print()


def print_repo_header(name: str, index: int, total: int):
    label = f"[{index}/{total}] {GITHUB_ORG}/{name}"
    print(f"\n{Colors.CYAN}╔{'─'*58}╗{Colors.NC}")
    print(f"{Colors.CYAN}║ {Colors.BOLD}{label:<57}{Colors.CYAN}║{Colors.NC}")
    print(f"{Colors.CYAN}╚{'─'*58}╝{Colors.NC}")


# ---------------------------------------------------------------------------
# Per-repo handler
# ---------------------------------------------------------------------------

def handle_repo(repo_name: str, index: int, total: int, draft: bool, dry_run: bool) -> dict:
    print_repo_header(repo_name, index, total)

    # Check branches exist
    print(f"  {Colors.GRAY}Checking branches...{Colors.NC}", end="", flush=True)
    if not branch_exists(repo_name, HEAD_BRANCH):
        print(f"\n  {Colors.YELLOW}Branch '{HEAD_BRANCH}' not found, skipping.{Colors.NC}")
        return {"repo": repo_name, "status": "skipped", "reason": f"no '{HEAD_BRANCH}' branch"}
    if not branch_exists(repo_name, BASE_BRANCH):
        print(f"\n  {Colors.YELLOW}Branch '{BASE_BRANCH}' not found, skipping.{Colors.NC}")
        return {"repo": repo_name, "status": "skipped", "reason": f"no '{BASE_BRANCH}' branch"}
    print(f" {Colors.GREEN}{HEAD_BRANCH}{Colors.NC} → {Colors.BLUE}{BASE_BRANCH}{Colors.NC}")

    # Check existing PR
    existing = pr_exists(repo_name, HEAD_BRANCH, BASE_BRANCH)
    if existing:
        print(f"  {Colors.YELLOW}PR already exists: {existing}{Colors.NC}")
        return {"repo": repo_name, "status": "exists", "url": existing}

    # Compare branches
    print(f"  {Colors.GRAY}Comparing {HEAD_BRANCH}...{BASE_BRANCH}...{Colors.NC}", end="", flush=True)
    compare = get_compare(repo_name, BASE_BRANCH, HEAD_BRANCH)
    ahead_by = compare.get("ahead_by", 0)
    commits = compare.get("commits", [])
    files = compare.get("files", [])
    print(f" {ahead_by} commit(s) ahead")

    if ahead_by == 0:
        print(f"  {Colors.YELLOW}Nothing to merge — {HEAD_BRANCH} is even with {BASE_BRANCH}, skipping.{Colors.NC}")
        return {"repo": repo_name, "status": "skipped", "reason": "no commits ahead"}

    if commits:
        print(f"  {Colors.CYAN}Recent commits:{Colors.NC}")
        for c in commits[:5]:
            msg = c.get("commit", {}).get("message", "").split("\n")[0]
            sha = c.get("sha", "")[:7]
            print(f"    {Colors.GRAY}{sha} {msg}{Colors.NC}")
        if len(commits) > 5:
            print(f"    {Colors.GRAY}... and {len(commits) - 5} more{Colors.NC}")

    if files:
        additions = sum(f.get("additions", 0) for f in files)
        deletions = sum(f.get("deletions", 0) for f in files)
        print(f"  {Colors.CYAN}Files changed: {len(files)}  +{additions} -{deletions}{Colors.NC}")

    # Auto-generate title and body
    title = f"Merge {HEAD_BRANCH} into {BASE_BRANCH}"
    body = "## Summary\n\n"
    for c in commits[:10]:
        msg = c.get("commit", {}).get("message", "").split("\n")[0]
        body += f"- {msg}\n"
    body += "\n Created with dev-to-main-pr.py"

    if dry_run:
        print(f"  {Colors.YELLOW}[DRY RUN] Would create: '{title}'{Colors.NC}")
        return {"repo": repo_name, "status": "dry_run", "title": title}

    print(f"  {Colors.GRAY}Creating PR...{Colors.NC}")
    ok, url_or_err = create_pr(repo_name, title, body, draft=draft)
    if ok:
        print(f"  {Colors.GREEN}PR created: {url_or_err}{Colors.NC}")
        return {"repo": repo_name, "status": "created", "url": url_or_err}
    else:
        print(f"  {Colors.RED}Failed: {url_or_err}{Colors.NC}")
        return {"repo": repo_name, "status": "failed", "error": url_or_err}


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    dry_run = "--dry-run" in sys.argv or "-n" in sys.argv
    draft = "--draft" in sys.argv or "-d" in sys.argv
    backwards = "--backwards" in sys.argv

    # Allow swapping the global HEAD/BASE branches when running backwards
    global HEAD_BRANCH, BASE_BRANCH
    if backwards:
        HEAD_BRANCH, BASE_BRANCH = BASE_BRANCH, HEAD_BRANCH

    print_banner()

    if not check_gh_auth():
        print(f"{Colors.RED}Error: GitHub CLI not authenticated. Run 'gh auth login' first.{Colors.NC}")
        sys.exit(1)

    if dry_run:
        print(f"{Colors.YELLOW}[DRY RUN MODE — no PRs will be created]{Colors.NC}\n")
    if draft:
        print(f"{Colors.YELLOW}[DRAFT mode — PRs will be created as drafts]{Colors.NC}\n")

    print(f"{Colors.CYAN}Fetching repositories from org...{Colors.NC}")
    repos = get_org_repos()
    if not repos:
        print(f"{Colors.RED}No repositories found or failed to fetch.{Colors.NC}")
        sys.exit(1)
    print(f"{Colors.CYAN}Targeting org: {Colors.BOLD}{GITHUB_ORG}{Colors.NC}")
    print(f"{Colors.CYAN}Repos: {len(repos)} · {HEAD_BRANCH} → {BASE_BRANCH}{Colors.NC}\n")

    # Scope selection
    print(f"{Colors.CYAN}Process all {len(repos)} repos? [Y/n/select]: {Colors.NC}", end="")
    scope = input().strip().lower()

    if scope == "n":
        print(f"{Colors.YELLOW}Aborted.{Colors.NC}")
        sys.exit(0)

    selected = list(repos)
    if scope == "select":
        print(f"\n{Colors.CYAN}Select repos (comma-separated numbers):{Colors.NC}")
        for i, r in enumerate(repos):
            print(f"  {Colors.BLUE}{i + 1}){Colors.NC} {r}")
        print(f"{Colors.CYAN}Selection: {Colors.NC}", end="")
        sel = input().strip()
        try:
            indices = [int(x.strip()) - 1 for x in sel.split(",")]
            selected = [repos[i] for i in indices if 0 <= i < len(repos)]
        except ValueError:
            print(f"{Colors.RED}Invalid selection, processing all.{Colors.NC}")

    print()

    # Process each repo
    results = []
    for i, repo_name in enumerate(selected, 1):
        result = handle_repo(repo_name=repo_name, index=i, total=len(selected), draft=draft, dry_run=dry_run)
        results.append(result)

    # Summary
    groups = {
        "created": (Colors.GREEN,  "Created"),
        "exists":  (Colors.YELLOW, "Already exists"),
        "dry_run": (Colors.YELLOW, "Dry-run"),
        "skipped": (Colors.YELLOW, "Skipped"),
        "failed":  (Colors.RED,    "Failed"),
    }

    print(f"\n{Colors.CYAN}{'='*60}{Colors.NC}")
    print(f"{Colors.BOLD}Summary{Colors.NC}")
    print(f"{Colors.CYAN}{'='*60}{Colors.NC}")
    for key, (color, label) in groups.items():
        items = [r for r in results if r["status"] == key]
        if not items:
            continue
        print(f"  {color}{label} ({len(items)}):{Colors.NC}")
        for r in items:
            detail = r.get("url") or r.get("title") or r.get("reason") or r.get("error") or ""
            print(f"    {Colors.GRAY}{r['repo']}{': ' + detail if detail else ''}{Colors.NC}")
    print(f"{Colors.CYAN}{'='*60}{Colors.NC}")


if __name__ == "__main__":
    main()
