#!/usr/bin/env python3
"""
Branch-merge PR Creator for Deepiri (can be Dev-to-Main or Main-to-Dev)
Creates PRs between two branches across the repos via GitHub CLI.
No local clones required — operates entirely through the GitHub API.

All PRs are automatically merged after creation.

Usage:
    python dev-to-main-pr.py                     # default: dev → main
    python dev-to-main-pr.py --draft             # create PRs as drafts
    python dev-to-main-pr.py --dry-run           # preview only, no PRs created
    python dev-to-main-pr.py --backwards         # reverse: main → dev
"""
import json
import re
import subprocess
import sys
from typing import Any, Optional


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
    """Run the GitHub CLI (`gh`) with the provided arguments.

    This is a thin wrapper around `subprocess.run` that captures output
    and decodes it to text for easier downstream handling.

    Returns:
        CompletedProcess: the result object from `subprocess.run`.
    """
    return subprocess.run(["gh"] + list(args), capture_output=True, text=True)


def gh_api(path: str) -> tuple[int, Any]:
    """Call `gh api <path>` and return a (exit_code, parsed_json) pair.

    The helper parses JSON output when present and returns an empty dict
    when the output is empty or cannot be decoded as JSON. This keeps
    callers resilient to non-JSON or empty responses.

    Args:
        path: The API path to call (e.g. "repos/owner/repo").

    Returns:
        A tuple of (exit_code, data) where `data` is the parsed JSON
        response or an empty dict.
    """
    result = subprocess.run(["gh", "api", path], capture_output=True, text=True)
    try:
        data = json.loads(result.stdout) if result.stdout.strip() else {}
    except json.JSONDecodeError:
        data = {}
    return result.returncode, data

def get_org_repos() -> list[str]:
    """Return a list of non-archived, non-fork repository names for the org.

    Uses `gh api --paginate` with a lightweight `jq` filter so this is
    efficient even for large orgs.
    """
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
    """Return True when the GitHub CLI is authenticated for the current user.

    This simply proxies `gh auth status` and checks the exit code.
    """
    return gh("auth", "status").returncode == 0


def repo_slug(repo_name: str) -> str:
    """Return the full repository slug `ORG/name` for `repo_name`."""
    return f"{GITHUB_ORG}/{repo_name}"


def branch_exists(repo_name: str, branch: str) -> bool:
    """Check whether `branch` exists in the given repository.

    Returns True only when the API call succeeds and returns branch metadata.
    """
    code, data = gh_api(f"repos/{repo_slug(repo_name)}/branches/{branch}")
    return code == 0 and isinstance(data, dict) and "name" in data


def get_compare(repo_name: str, base: str, head: str) -> dict:
    """Return the compare object for `base...head` or an empty dict on error.

    The compare object includes fields like `ahead_by`, `commits`, and `files`.
    """
    code, data = gh_api(f"repos/{repo_slug(repo_name)}/compare/{base}...{head}")
    if code != 0 or not isinstance(data, dict):
        return {}
    return data


def pr_exists(repo_name: str, head_branch: str, base_branch: str) -> Optional[str]:
    """Return the URL of an existing PR matching `head_branch -> base_branch`.

    If multiple PRs exist we pick the first returned; callers only need to
    know whether one exists and what its URL is.
    """
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
    """Create a pull request and return (success, url_or_error).

    The success path returns the PR URL as reported by `gh pr create`.
    On failure the helper returns (False, error_message).
    """
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


def enable_auto_merge(repo_name: str, pr_url: str) -> tuple[bool, str]:
    """Enable GitHub's auto-merge on the given PR URL using GraphQL.

    The GitHub REST API does not provide an endpoint for enabling auto-merge;
    the GraphQL `enablePullRequestAutoMerge` mutation must be used instead.
    This helper extracts the numeric PR number from `pr_url`, fetches the
    PR's GraphQL node ID, and runs the mutation. It returns (True, message)
    on success or (False, error_text) when any step fails.
    """
    repo = repo_slug(repo_name)
    match = re.search(r"(?:/pull/|#)(\d+)$", pr_url)
    if not match:
        return False, f"Unable to parse PR number from '{pr_url}'"

    pr_number = match.group(1)

    # Fetch the PR node ID (required by the GraphQL mutation)
    node_result = gh("api", f"repos/{repo}/pulls/{pr_number}", "--jq", ".node_id")
    if node_result.returncode != 0:
        return False, (node_result.stderr or node_result.stdout).strip()

    pull_request_id = node_result.stdout.strip().strip('"')
    if not pull_request_id:
        return False, f"Unable to fetch GraphQL node id for PR '{pr_url}'"

    graphql_query = """
    mutation($pullRequestId: ID!) {
      enablePullRequestAutoMerge(input: {pullRequestId: $pullRequestId, mergeMethod: SQUASH}) {
        pullRequest {
          url
          autoMergeRequest {
            enabledAt
          }
        }
      }
    }
    """

    result = subprocess.run(
        [
            "gh", "api", "graphql",
            "-f", f"query={graphql_query}",
            "-f", f"pullRequestId={pull_request_id}",
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        return True, "Auto-merge enabled"
    return False, (result.stderr or result.stdout).strip()

# Dynamically list all Deepiri repos

def get_all_repos() -> list[str]:
    # Logic to make sure this still works over 100 repos
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

def print_banner(num_repos: int):
    direction = f"{HEAD_BRANCH} → {BASE_BRANCH}"
    print(f"{Colors.CYAN}")
    print(f"╔{'═'*60}╗")
    print(f"║{'  Dev → Main PR Creator (Deepiri)  ':^60}║")
    print(f"║{f'  {num_repos} repos · {direction} · GitHub API  ':^60}║")
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
        print(f"  {Colors.GRAY}PR exists, enabling auto-merge...{Colors.NC}")
        ok, msg = enable_auto_merge(repo_name, existing)
        if ok:
            print(f"  {Colors.GREEN}Auto-merge enabled on existing PR: {existing}{Colors.NC}")
            return {"repo": repo_name, "status": "auto_merged", "url": existing}
        else:
            print(f"  {Colors.YELLOW}Auto-merge failed: {msg}{Colors.NC}")
            return {"repo": repo_name, "status": "exists", "url": existing, "auto_merge_error": msg}

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
    body += "\nCreated with dev-to-main-pr.py"

    if dry_run:
        print(f"  {Colors.YELLOW}[DRY RUN] Would create PR and auto-merge: '{title}'{Colors.NC}")
        return {"repo": repo_name, "status": "dry_run", "title": title}

    print(f"  {Colors.GRAY}Creating PR...{Colors.NC}")
    ok, url_or_err = create_pr(repo_name, title, body, draft=draft)
    if ok:
        print(f"  {Colors.GREEN}PR created: {url_or_err}{Colors.NC}")

        print(f"  {Colors.GRAY}Enabling auto-merge...{Colors.NC}")
        ok_am, msg_am = enable_auto_merge(repo_name, url_or_err)
        if ok_am:
            print(f"  {Colors.GREEN}Auto-merge enabled: {url_or_err}{Colors.NC}")
            return {"repo": repo_name, "status": "auto_merged", "url": url_or_err}
        else:
            print(f"  {Colors.YELLOW}Auto-merge failed: {msg_am}{Colors.NC}")
            return {"repo": repo_name, "status": "created", "url": url_or_err, "auto_merge_error": msg_am}
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

    all_repos = get_all_repos()
    selected = list(all_repos)
    print_banner(len(all_repos))
    
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
    print(f"{Colors.CYAN}Repos: {len(all_repos)} · {HEAD_BRANCH} → {BASE_BRANCH}{Colors.NC}\n")

    # Scope selection
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

    # Process each repo
    results = []
    for i, repo_name in enumerate(selected, 1):
        result = handle_repo(repo_name=repo_name, index=i, total=len(selected), draft=draft, dry_run=dry_run)
        results.append(result)

    # Summary
    groups = {
        "auto_merged": (Colors.GREEN, "Auto-merged"),
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