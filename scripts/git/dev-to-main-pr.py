#!/usr/bin/env python3
"""
Branch-merge PR Creator for Deepiri (can be Dev-to-Main or Main-to-Dev)
Creates PRs between two branches across the repos via GitHub CLI.
No local clones required — operates entirely through the GitHub API.

Merge behavior:
  All merges use [skip ci] in the commit message so GitHub Actions skip push workflows.
  Tries direct branch merge first (no PR = no pull_request CI). Falls back to
  PR + admin merge only when direct merge fails (conflicts / protection).

Usage:
    python dev-to-main-pr.py                     # default: dev → main
    python dev-to-main-pr.py --draft             # create PRs as drafts
    python dev-to-main-pr.py --dry-run           # preview only, no PRs created
    python dev-to-main-pr.py --backwards         # main → dev, then dev → main
"""
import json
import re
import subprocess
import sys
import time
from typing import Any, Optional

SKIP_CI = "[skip ci]"


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


# ---------------------------------------------------------------------------
# GitHub helpers (all via gh CLI, no local git needed)
# ---------------------------------------------------------------------------

def gh(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["gh"] + list(args), capture_output=True, text=True)


def gh_api(path: str) -> tuple[int, Any]:
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


def create_pr(
    repo_name: str,
    head_branch: str,
    base_branch: str,
    title: str,
    body: str,
    draft: bool = False,
) -> tuple[bool, str]:
    args = [
        "pr", "create",
        "--repo", repo_slug(repo_name),
        "--head", head_branch,
        "--base", base_branch,
        "--title", title,
        "--body", body,
    ]
    if draft:
        args.append("--draft")
    result = gh(*args)
    if result.returncode == 0:
        return True, result.stdout.strip()
    return False, (result.stderr or result.stdout).strip()


def merge_commit_message(head_branch: str, base_branch: str) -> str:
    return f"Merge {head_branch} into {base_branch} {SKIP_CI}"


def direct_merge(
    repo_name: str,
    base_branch: str,
    head_branch: str,
) -> tuple[bool, str, Optional[str]]:
    """Merge branches via API — no PR opened, so pull_request workflows never fire."""
    result = subprocess.run(
        [
            "gh", "api", f"repos/{repo_slug(repo_name)}/merges",
            "-X", "POST",
            "-f", f"base={base_branch}",
            "-f", f"head={head_branch}",
            "-f", f"commit_message={merge_commit_message(head_branch, base_branch)}",
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        try:
            data = json.loads(result.stdout)
            sha = (data.get("sha") or "")[:7]
            url = data.get("html_url") or ""
            return True, f"Direct merge {SKIP_CI} ({sha})", url
        except json.JSONDecodeError:
            return True, f"Direct merge {SKIP_CI}", None

    err = (result.stderr or result.stdout).strip()
    if "409" in err or "Merge conflict" in err or "not mergeable" in err.lower():
        return False, "Merge conflict", None
    return False, err, None


def get_pr_number(pr_url: str) -> Optional[str]:
    match = re.search(r"(?:/pull/|#)(\d+)$", pr_url)
    return match.group(1) if match else None


def get_mergeable(repo_name: str, pr_url: str) -> Optional[bool]:
    """Return mergeability: True, False, or None while GitHub is still computing."""
    pr_number = get_pr_number(pr_url)
    if not pr_number:
        return None
    code, data = gh_api(f"repos/{repo_slug(repo_name)}/pulls/{pr_number}")
    if code != 0 or not isinstance(data, dict):
        return None
    return data.get("mergeable")


def wait_for_mergeable(
    repo_name: str,
    pr_url: str,
    max_attempts: int = 15,
    delay_seconds: float = 2.0,
) -> Optional[bool]:
    """Poll until mergeability is known or attempts are exhausted."""
    for _ in range(max_attempts):
        mergeable = get_mergeable(repo_name, pr_url)
        if mergeable is not None:
            return mergeable
        time.sleep(delay_seconds)
    return None


def admin_merge(
    repo_name: str,
    pr_url: str,
    head_branch: str,
    base_branch: str,
) -> tuple[bool, str]:
    """Force-merge a PR using --admin. Commit message includes [skip ci]."""
    result = gh(
        "pr", "merge", pr_url,
        "--repo", repo_slug(repo_name),
        "--squash",
        "--admin",
        "--delete-branch=false",
        "--subject", merge_commit_message(head_branch, base_branch),
    )
    if result.returncode == 0:
        return True, f"Merged with --admin {SKIP_CI}"
    return False, (result.stderr or result.stdout).strip()


def merge_pr(
    repo_name: str,
    pr_url: str,
    head_branch: str,
    base_branch: str,
) -> tuple[bool, str]:
    """Admin-merge an existing PR with [skip ci] on the squash commit."""
    print(f"  {Colors.GRAY}Admin merge {SKIP_CI}...{Colors.NC}")
    print(f"  {Colors.GRAY}Checking mergeability...{Colors.NC}")
    mergeable = wait_for_mergeable(repo_name, pr_url, max_attempts=10)
    if mergeable is False:
        return False, "PR has merge conflicts"
    return admin_merge(repo_name, pr_url, head_branch, base_branch)


def get_all_repos() -> list[str]:
    repos = []
    page = 1

    while True:
        code, data = gh_api(f"orgs/{GITHUB_ORG}/repos?per_page=100&page={page}")
        if code != 0 or not isinstance(data, list) or not data:
            break

        repos.extend([repo["name"] for repo in data])
        page += 1

    return repos


# ---------------------------------------------------------------------------
# Display helpers
# ---------------------------------------------------------------------------

def print_banner(num_repos: int, direction: str, backwards: bool = False):
    title = "Dev ↔ Main PR Creator (Deepiri)" if backwards else "Dev → Main PR Creator (Deepiri)"
    print(f"{Colors.CYAN}")
    print(f"╔{'═'*60}╗")
    print(f"║{title:^60}║")
    print(f"║{f'  {num_repos} repos · {direction} · GitHub API  ':^60}║")
    if backwards:
        print(f"║{'  backwards: main→dev, then dev→main (all [skip ci])  ':^60}║")
    print(f"╚{'═'*60}╝{Colors.NC}")
    print()


def print_repo_header(name: str, index: int, total: int):
    label = f"[{index}/{total}] {GITHUB_ORG}/{name}"
    print(f"\n{Colors.CYAN}╔{'─'*58}╗{Colors.NC}")
    print(f"{Colors.CYAN}║ {Colors.BOLD}{label:<57}{Colors.CYAN}║{Colors.NC}")
    print(f"{Colors.CYAN}╚{'─'*58}╝{Colors.NC}")


def print_direction_header(head_branch: str, base_branch: str):
    print(f"  {Colors.CYAN}→ {head_branch} → {base_branch} ({SKIP_CI}){Colors.NC}")


# ---------------------------------------------------------------------------
# Per-repo handler
# ---------------------------------------------------------------------------

def merge_direction(
    repo_name: str,
    head_branch: str,
    base_branch: str,
    draft: bool,
    dry_run: bool,
) -> dict:
    """Merge one branch direction with [skip ci]. Direct merge first, PR fallback."""
    print_direction_header(head_branch, base_branch)

    if not branch_exists(repo_name, head_branch):
        print(f"  {Colors.YELLOW}Branch '{head_branch}' not found, skipping.{Colors.NC}")
        return {"status": "skipped", "reason": f"no '{head_branch}' branch"}
    if not branch_exists(repo_name, base_branch):
        print(f"  {Colors.YELLOW}Branch '{base_branch}' not found, skipping.{Colors.NC}")
        return {"status": "skipped", "reason": f"no '{base_branch}' branch"}

    existing = pr_exists(repo_name, head_branch, base_branch)
    if existing:
        print(f"  {Colors.GRAY}Open PR exists: {existing}{Colors.NC}")
        if dry_run:
            print(f"  {Colors.YELLOW}[DRY RUN] Would admin-merge existing PR {SKIP_CI}{Colors.NC}")
            return {"status": "dry_run", "url": existing}
        ok_adm, msg_adm = merge_pr(repo_name, existing, head_branch, base_branch)
        if ok_adm:
            print(f"  {Colors.GREEN}{msg_adm}: {existing}{Colors.NC}")
            return {"status": "merged", "url": existing}
        if msg_adm == "PR has merge conflicts":
            print(f"  {Colors.YELLOW}PR has merge conflicts, leaving for manual merge.{Colors.NC}")
        else:
            print(f"  {Colors.RED}Admin merge failed: {msg_adm}{Colors.NC}")
        return {"status": "exists", "url": existing, "error": msg_adm}

    print(f"  {Colors.GRAY}Comparing {head_branch}...{base_branch}...{Colors.NC}", end="", flush=True)
    compare = get_compare(repo_name, base_branch, head_branch)
    ahead_by = compare.get("ahead_by", 0)
    commits = compare.get("commits", [])
    files = compare.get("files", [])
    print(f" {ahead_by} commit(s) ahead")

    if ahead_by == 0:
        print(f"  {Colors.YELLOW}Nothing to merge — even with {base_branch}, skipping.{Colors.NC}")
        return {"status": "skipped", "reason": "no commits ahead"}

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

    title = merge_commit_message(head_branch, base_branch)
    body = "## Summary\n\n"
    for c in commits[:10]:
        msg = c.get("commit", {}).get("message", "").split("\n")[0]
        body += f"- {msg}\n"
    body += f"\nCreated with dev-to-main-pr.py\n\n{SKIP_CI}"

    if dry_run:
        print(f"  {Colors.YELLOW}[DRY RUN] Would direct-merge {SKIP_CI}: '{title}'{Colors.NC}")
        return {"status": "dry_run", "title": title}

    print(f"  {Colors.GRAY}Direct merge {SKIP_CI}...{Colors.NC}")
    ok_direct, msg_direct, url_direct = direct_merge(repo_name, base_branch, head_branch)
    if ok_direct:
        print(f"  {Colors.GREEN}{msg_direct}{Colors.NC}")
        if url_direct:
            print(f"  {Colors.GRAY}{url_direct}{Colors.NC}")
        return {"status": "merged", "url": url_direct or ""}

    print(f"  {Colors.YELLOW}Direct merge failed: {msg_direct}{Colors.NC}")
    print(f"  {Colors.GRAY}Falling back to PR + admin merge...{Colors.NC}")

    ok, url_or_err = create_pr(repo_name, head_branch, base_branch, title, body, draft=draft)
    if not ok:
        print(f"  {Colors.RED}Failed: {url_or_err}{Colors.NC}")
        return {"status": "failed", "error": url_or_err}

    print(f"  {Colors.GREEN}PR created: {url_or_err}{Colors.NC}")
    ok_adm, msg_adm = merge_pr(repo_name, url_or_err, head_branch, base_branch)
    if ok_adm:
        print(f"  {Colors.GREEN}{msg_adm}: {url_or_err}{Colors.NC}")
        return {"status": "merged", "url": url_or_err}

    if msg_adm == "PR has merge conflicts":
        print(f"  {Colors.YELLOW}PR has merge conflicts, leaving for manual merge.{Colors.NC}")
    else:
        print(f"  {Colors.RED}Admin merge failed: {msg_adm}{Colors.NC}")
    return {"status": "created", "url": url_or_err, "error": msg_adm}


def handle_repo(
    repo_name: str,
    index: int,
    total: int,
    draft: bool,
    dry_run: bool,
    backwards: bool = False,
) -> dict:
    print_repo_header(repo_name, index, total)

    if backwards:
        main_to_dev = merge_direction(repo_name, "main", "dev", draft, dry_run)
        dev_to_main = merge_direction(repo_name, "dev", "main", draft, dry_run)
        statuses = {main_to_dev["status"], dev_to_main["status"]}
        if "merged" in statuses:
            overall = "merged"
        elif "created" in statuses or "exists" in statuses:
            overall = "partial"
        elif "failed" in statuses:
            overall = "failed"
        elif statuses == {"skipped"}:
            overall = "skipped"
        else:
            overall = "skipped"
        return {
            "repo": repo_name,
            "status": overall,
            "main_to_dev": main_to_dev,
            "dev_to_main": dev_to_main,
        }

    result = merge_direction(repo_name, "dev", "main", draft, dry_run)
    return {"repo": repo_name, **result}


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    dry_run = "--dry-run" in sys.argv or "-n" in sys.argv
    draft = "--draft" in sys.argv or "-d" in sys.argv
    backwards = "--backwards" in sys.argv

    all_repos = get_all_repos()
    direction = "main → dev, then dev → main" if backwards else "dev → main"
    print_banner(len(all_repos), direction, backwards=backwards)

    if not check_gh_auth():
        print(f"{Colors.RED}Error: GitHub CLI not authenticated. Run 'gh auth login' first.{Colors.NC}")
        sys.exit(1)

    if dry_run:
        print(f"{Colors.YELLOW}[DRY RUN MODE — no PRs will be created]{Colors.NC}\n")
    if draft:
        print(f"{Colors.YELLOW}[DRAFT mode — PRs will be created as drafts]{Colors.NC}\n")
    if backwards:
        print(f"{Colors.YELLOW}[BACKWARDS — main→dev then dev→main, all merges {SKIP_CI}]{Colors.NC}\n")
    else:
        print(f"{Colors.YELLOW}[All merges use {SKIP_CI} — direct merge when possible]{Colors.NC}\n")

    print(f"{Colors.CYAN}Fetching repositories from org...{Colors.NC}")
    repos = get_org_repos()
    if not repos:
        print(f"{Colors.RED}No repositories found or failed to fetch.{Colors.NC}")
        sys.exit(1)
    print(f"{Colors.CYAN}Targeting org: {Colors.BOLD}{GITHUB_ORG}{Colors.NC}")
    print(f"{Colors.CYAN}Repos: {len(all_repos)} · {direction}{Colors.NC}\n")

    print(f"{Colors.CYAN}Process all {len(all_repos)} repos? [Y/n/select]: {Colors.NC}", end="")
    scope = input().strip().lower()

    if scope == "n":
        print(f"{Colors.YELLOW}Aborted.{Colors.NC}")
        sys.exit(0)

    selected = list(all_repos)
    if scope == "select":
        print(f"\n{Colors.CYAN}Select repos (comma-separated numbers):{Colors.NC}")
        for i, r in enumerate(all_repos):
            print(f"  {Colors.BLUE}{i + 1}){Colors.NC} {r}")
        print(f"{Colors.CYAN}Selection: {Colors.NC}", end="")
        sel = input().strip()
        try:
            indices = [int(x.strip()) - 1 for x in sel.split(",")]
            selected = [all_repos[i] for i in indices if 0 <= i < len(all_repos)]
        except ValueError:
            print(f"{Colors.RED}Invalid selection, processing all.{Colors.NC}")

    print()

    results = []
    for i, repo_name in enumerate(selected, 1):
        result = handle_repo(
            repo_name=repo_name,
            index=i,
            total=len(selected),
            draft=draft,
            dry_run=dry_run,
            backwards=backwards,
        )
        results.append(result)

    groups = {
        "merged": (Colors.GREEN, "Merged"),
        "partial": (Colors.YELLOW, "Partial (PR open)"),
        "dry_run": (Colors.YELLOW, "Dry-run"),
        "skipped": (Colors.YELLOW, "Skipped"),
        "failed": (Colors.RED, "Failed"),
        "created": (Colors.GREEN, "Created (unmerged)"),
        "exists": (Colors.YELLOW, "Already exists"),
    }

    print(f"\n{Colors.CYAN}{'='*60}{Colors.NC}")
    print(f"{Colors.BOLD}Summary{Colors.NC}")
    print(f"{Colors.CYAN}{'='*60}{Colors.NC}")
    for key, (color, label) in groups.items():
        items = [r for r in results if r.get("status") == key]
        if not items:
            continue
        print(f"  {color}{label} ({len(items)}):{Colors.NC}")
        for r in items:
            if backwards and "main_to_dev" in r:
                m = r["main_to_dev"]
                d = r["dev_to_main"]
                detail = (
                    f"main→dev: {m.get('status')}"
                    f"{(' ' + m['url']) if m.get('url') else ''}"
                    f" | dev→main: {d.get('status')}"
                    f"{(' ' + d['url']) if d.get('url') else ''}"
                )
            else:
                detail = r.get("url") or r.get("title") or r.get("reason") or r.get("error") or ""
            print(f"    {Colors.GRAY}{r['repo']}{': ' + detail if detail else ''}{Colors.NC}")
    print(f"{Colors.CYAN}{'='*60}{Colors.NC}")


if __name__ == "__main__":
    main()
