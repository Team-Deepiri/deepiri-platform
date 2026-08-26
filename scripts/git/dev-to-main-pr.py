#!/usr/bin/env python3
"""
Branch-merge PR Creator for Deepiri (can be Dev-to-Main or Main-to-Dev)
Creates PRs between two branches across the repos via GitHub CLI.
No local clones required — operates entirely through the GitHub API.

All PRs are automatically merged after creation. If auto-merge is blocked by
branch protection rules and there are no merge conflicts, the script retries
with a plain squash merge, which honors the caller's branch-protection bypass
allowance (e.g. Support Team). It only falls back to `gh pr merge --admin`
if the caller holds repo admin rights and the plain merge is rejected.

Every processed repo gets a DevOps label (created if missing; existing
case variants like devops/DEVOPS are reused). Every PR this script creates
or finds (dev→main and, with --backwards, main→dev) is tagged with that label.

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

# Canonical label name when creating for repos that do not have one yet.
# Matching is case-insensitive (devops / DevOps / DEVOPS all count); reuse the
# existing exact name when present, otherwise create "DevOps".
DEVOPS_LABEL_CREATE_NAME = "DevOps"
DEVOPS_LABEL_COLOR = "e08d13"
DEVOPS_LABEL_DESCRIPTION = "Infrastructure or deployment changes"


# ---------------------------------------------------------------------------
# GitHub helpers (all via gh CLI, no local git needed)
# ---------------------------------------------------------------------------

def gh(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["gh"] + list(args), capture_output=True, text=True)


def gh_api(path: str, *extra: str) -> tuple[int, Any]:
    result = subprocess.run(["gh", "api", path, *extra], capture_output=True, text=True)
    try:
        data = json.loads(result.stdout) if result.stdout.strip() else {}
    except json.JSONDecodeError:
        data = {}
    return result.returncode, data


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


def _normalize_devops_key(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", name.lower())


def find_existing_devops_label(repo_name: str) -> Optional[str]:
    """Return the exact label name if the repo already has a devops-like label."""
    result = gh(
        "label", "list",
        "--repo", repo_slug(repo_name),
        "--json", "name",
        "--limit", "200",
    )
    if result.returncode != 0 or not result.stdout.strip():
        return None
    try:
        labels = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None
    wanted = _normalize_devops_key(DEVOPS_LABEL_CREATE_NAME)
    for label in labels:
        name = label.get("name") or ""
        if _normalize_devops_key(name) == wanted:
            return name
    return None


def ensure_devops_label(repo_name: str, dry_run: bool = False) -> tuple[bool, str]:
    """
    Ensure EVERY repo has a DevOps label.

    - If any case/variant already exists (devops / DevOps / DEVOPS), reuse that exact name.
    - If missing, create `DevOps` on that repo.
    """
    existing = find_existing_devops_label(repo_name)
    if existing:
        return True, existing

    if dry_run:
        print(
            f"  {Colors.YELLOW}[DRY RUN] Would create label "
            f"'{DEVOPS_LABEL_CREATE_NAME}' on {repo_slug(repo_name)}{Colors.NC}"
        )
        return True, DEVOPS_LABEL_CREATE_NAME

    result = gh(
        "label", "create", DEVOPS_LABEL_CREATE_NAME,
        "--repo", repo_slug(repo_name),
        "--color", DEVOPS_LABEL_COLOR,
        "--description", DEVOPS_LABEL_DESCRIPTION,
        "--force",
    )
    if result.returncode == 0:
        print(
            f"  {Colors.GREEN}Created label '{DEVOPS_LABEL_CREATE_NAME}' "
            f"on {repo_slug(repo_name)}{Colors.NC}"
        )
        return True, DEVOPS_LABEL_CREATE_NAME

    # Race: another run created it, or --force updated it — re-resolve.
    existing = find_existing_devops_label(repo_name)
    if existing:
        return True, existing

    err = (result.stderr or result.stdout).strip()
    print(f"  {Colors.RED}Failed to create devops label on {repo_name}: {err}{Colors.NC}")
    return False, err


def apply_devops_label(repo_name: str, pr_url: str, dry_run: bool = False) -> bool:
    """Ensure repo has devops label, then tag this PR (dev→main and main→dev alike)."""
    ok, label_or_err = ensure_devops_label(repo_name, dry_run=dry_run)
    if not ok:
        return False

    label_name = label_or_err
    pr_number = get_pr_number(pr_url)
    if not pr_number:
        print(f"  {Colors.YELLOW}Could not parse PR number from {pr_url}{Colors.NC}")
        return False

    if dry_run:
        print(
            f"  {Colors.YELLOW}[DRY RUN] Would label PR #{pr_number} "
            f"with '{label_name}'{Colors.NC}"
        )
        return True

    # Use gh api REST (still gh auth — no extra PAT). Avoid `gh pr edit --add-label`
    # which fails on Projects (classic) GraphQL deprecation.
    result = gh(
        "api",
        f"repos/{repo_slug(repo_name)}/issues/{pr_number}/labels",
        "-X", "POST",
        "-f", f"labels[]={label_name}",
    )
    if result.returncode == 0:
        print(f"  {Colors.GREEN}Labeled PR #{pr_number} with '{label_name}'{Colors.NC}")
        return True

    err = (result.stderr or result.stdout).strip()
    if "already" in err.lower():
        print(f"  {Colors.GREEN}Labeled PR #{pr_number} with '{label_name}'{Colors.NC}")
        return True
    print(f"  {Colors.YELLOW}Could not label PR #{pr_number}: {err}{Colors.NC}")
    return False


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


def merge_with_admin_fallback(repo_name: str, pr_url: str, head_branch: str = "", base_branch: str = "") -> tuple[bool, str]:
    """Retry merge with --admin unless GitHub confirms merge conflicts."""
    print(f"  {Colors.GRAY}Checking mergeability...{Colors.NC}")
    mergeable = wait_for_mergeable(repo_name, pr_url)
    if mergeable is False:
        return False, "PR has merge conflicts"

    print(f"  {Colors.GRAY}Retrying with --admin...{Colors.NC}")
    return admin_merge(repo_name, pr_url, head_branch, base_branch)


def enable_auto_merge(repo_name: str, pr_url: str) -> tuple[bool, str]:
    repo = repo_slug(repo_name)
    pr_number = get_pr_number(pr_url)
    if not pr_number:
        return False, f"Unable to parse PR number from '{pr_url}'"

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

    graphql_result = gh(
        "api",
        "graphql",
        "-f",
        f"query={graphql_query}",
        "-f",
        f"pullRequestId={pull_request_id}",
    )
    if graphql_result.returncode != 0:
        return False, (graphql_result.stderr or graphql_result.stdout).strip()

    try:
        payload = json.loads(graphql_result.stdout or "{}")
    except json.JSONDecodeError:
        return False, "Failed to parse GraphQL response while enabling auto-merge"

    errors = payload.get("errors")
    if errors:
        return False, json.dumps(errors)

    enabled_at = (
        payload.get("data", {})
        .get("enablePullRequestAutoMerge", {})
        .get("pullRequest", {})
        .get("autoMergeRequest", {})
        .get("enabledAt")
    )
    if enabled_at:
        return True, "Auto-merge enabled"

    return False, "Auto-merge was not enabled"

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
    """Merge a PR via squash. Relies on the caller's branch-protection bypass
    allowance (e.g. Support Team) rather than --admin, which requires repo
    *admin* permission and fails for maintain/write-level accounts even when
    they're on the review-bypass list. Falls back to --admin only if the
    caller does happen to have admin rights and the plain merge is rejected.
    """
    base_args = [
        "pr", "merge", pr_url,
        "--repo", repo_slug(repo_name),
        "--squash",
        "--delete-branch=false",
        "--subject", merge_commit_message(head_branch, base_branch),
    ]
    result = gh(*base_args)
    if result.returncode == 0:
        return True, f"Merged {SKIP_CI}"

    err = (result.stderr or result.stdout).strip()
    result_admin = gh(*base_args[:3], "--admin", *base_args[3:])
    if result_admin.returncode == 0:
        return True, f"Merged with --admin {SKIP_CI}"
    return False, err or (result_admin.stderr or result_admin.stdout).strip()


def merge_pr(
    repo_name: str,
    pr_url: str,
    head_branch: str,
    base_branch: str,
) -> tuple[bool, str]:
    """Merge an existing PR with [skip ci] on the squash commit."""
    print(f"  {Colors.GRAY}Merging {SKIP_CI}...{Colors.NC}")
    print(f"  {Colors.GRAY}Checking mergeability...{Colors.NC}")
    mergeable = wait_for_mergeable(repo_name, pr_url, max_attempts=10)
    if mergeable is False:
        return False, "PR has merge conflicts"
    return admin_merge(repo_name, pr_url, head_branch, base_branch)


def get_all_repos() -> list[str]:
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
        apply_devops_label(repo_name, existing, dry_run=dry_run)
        if dry_run:
            print(f"  {Colors.YELLOW}[DRY RUN] Would admin-merge existing PR {SKIP_CI}{Colors.NC}")
            return {"status": "dry_run", "url": existing}
        ok_adm, msg_adm = merge_pr(repo_name, existing, head_branch, base_branch)
        if ok_adm:
            print(f"  {Colors.GREEN}{msg_adm}: {existing}{Colors.NC}")
            return {"status": "merged", "url": existing}
        if msg_adm == "PR has merge conflicts":
            print(f"  {Colors.YELLOW}PR has merge conflicts, leaving for manual merge.{Colors.NC}")
            return {"status": "exists", "url": existing, "error": msg_adm}
        print(f"  {Colors.YELLOW}Auto-merge failed: {msg_adm}. Trying admin fallback...{Colors.NC}")
        ok_adm, msg_adm = merge_with_admin_fallback(repo_name, existing, head_branch, base_branch)
        if ok_adm:
            print(f"  {Colors.GREEN}Admin-merged: {existing}{Colors.NC}")
            return {"repo": repo_name, "status": "auto_merged", "url": existing}
        if msg_adm == "PR has merge conflicts":
            print(f"  {Colors.YELLOW}PR has merge conflicts, leaving for manual merge.{Colors.NC}")
        else:
            print(f"  {Colors.RED}Admin merge failed: {msg_adm}{Colors.NC}")
        return {"repo": repo_name, "status": "exists", "url": existing, "auto_merge_error": msg_adm}

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
    body += "\nCreated with dev-to-main-pr.py"

    if dry_run:
        print(f"  {Colors.YELLOW}[DRY RUN] Would create PR, label DevOps, and auto-merge: '{title}'{Colors.NC}")
        ensure_devops_label(repo_name, dry_run=True)
        return {"repo": repo_name, "status": "dry_run", "title": title}

    ok, url_or_err = create_pr(repo_name, head_branch, base_branch, title, body, draft=draft)
    if ok:
        print(f"  {Colors.GREEN}PR created: {url_or_err}{Colors.NC}")
        apply_devops_label(repo_name, url_or_err, dry_run=False)

        print(f"  {Colors.GRAY}Enabling auto-merge...{Colors.NC}")
        ok_am, msg_am = enable_auto_merge(repo_name, url_or_err)
        if ok_am:
            print(f"  {Colors.GREEN}Auto-merge enabled: {url_or_err}{Colors.NC}")
            return {"repo": repo_name, "status": "auto_merged", "url": url_or_err}
        else:
            print(f"  {Colors.YELLOW}Auto-merge failed: {msg_am}. Trying admin fallback...{Colors.NC}")
            ok_adm, msg_adm = merge_with_admin_fallback(repo_name, url_or_err, head_branch, base_branch)
            if ok_adm:
                print(f"  {Colors.GREEN}Admin-merged: {url_or_err}{Colors.NC}")
                return {"repo": repo_name, "status": "auto_merged", "url": url_or_err}
            if msg_adm == "PR has merge conflicts":
                print(f"  {Colors.YELLOW}PR has merge conflicts, leaving for manual merge.{Colors.NC}")
            else:
                print(f"  {Colors.RED}Admin merge failed: {msg_adm}{Colors.NC}")
            return {"repo": repo_name, "status": "created", "url": url_or_err, "auto_merge_error": msg_adm}
    else:
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

    # Every repo gets a DevOps label (create if missing), including --backwards runs.
    ensure_devops_label(repo_name, dry_run=dry_run)

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
        print(
            f"{Colors.YELLOW}"
            f"[All merges use {SKIP_CI} — direct merge first; PR fallback uses --admin]"
            f"{Colors.NC}\n"
        )

    print(f"{Colors.CYAN}Fetching repositories from org...{Colors.NC}")
    if not all_repos:
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
