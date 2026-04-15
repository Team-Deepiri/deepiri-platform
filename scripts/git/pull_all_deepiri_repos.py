#!/usr/bin/env python3
"""
Pull All Deepiri Repositories
-----------------------------
Interactive script to manage the entire Deepiri workspace.
Fetches all repositories from the Team-Deepiri organization using:
  1. GitHub Personal Access Token (GITHUB_TOKEN or GH_TOKEN)
  2. Fallback to GitHub CLI (gh repo list)

Then clones or pulls them based on whether they are submodules or sibling repositories.

Usage:
  python3 scripts/git/pull_all_deepiri_repos.py
"""

import os
import subprocess
import sys
import json
import argparse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from typing import List, Dict, Set

# --- Configuration ---
ORG = "Team-Deepiri"
PLATFORM_REPO = "deepiri-platform"

def get_repo_root():
    try:
        root = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], 
                                      stderr=subprocess.STDOUT).decode().strip()
        return root
    except subprocess.CalledProcessError:
        return os.getcwd()

REPO_ROOT = get_repo_root()
SIBLING_DIR = os.path.dirname(REPO_ROOT)

# --- Helpers ---

def run_command(cmd: List[str], cwd: str = REPO_ROOT) -> str:
    try:
        result = subprocess.run(cmd, cwd=cwd, check=True, capture_output=True, text=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error running {' '.join(cmd)}: {e.stderr}")
        return ""

def check_auth():
    """Checks if either gh CLI is authenticated or a token is provided."""
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        return True
    
    try:
        if subprocess.run(["gh", "auth", "status"], capture_output=True).returncode == 0:
            return True
    except FileNotFoundError:
        pass
        
    print("Error: Neither GITHUB_TOKEN/GH_TOKEN found nor authenticated with gh CLI.")
    print("Please run 'gh auth login' or set one of the environment variables.")
    sys.exit(1)

def fetch_org_repos() -> List[Dict]:
    """Fetches all repositories from the organization using GitHub PAT or gh CLI."""
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    repos = []

    if token:
        print(f"Fetching repositories from {ORG} via GitHub API...")
        page = 1
        while True:
            url = f"https://api.github.com/orgs/{ORG}/repos?per_page=100&page={page}"
            req = urllib.request.Request(url)
            req.add_header("Authorization", f"token {token}")
            req.add_header("Accept", "application/vnd.github.v3+json")
            req.add_header("User-Agent", "Deepiri-Workspace-Tool")
            
            try:
                with urllib.request.urlopen(req) as response:
                    data = json.loads(response.read().decode())
                    if not data:
                        break
                    for r in data:
                        repos.append({
                            "name": r["name"],
                            "sshUrl": r["ssh_url"],
                            "description": r.get("description", "")
                        })
                    if len(data) < 100:
                        break
                    page += 1
            except Exception as e:
                print(f"Error fetching from API: {e}")
                # Fallback to gh if API fails
                if not repos:
                    print("Attempting fallback to gh CLI...")
                    return fetch_via_gh()
                break
    else:
        return fetch_via_gh()

    return repos

def fetch_via_gh() -> List[Dict]:
    """Fallback fetcher using gh CLI."""
    print(f"Fetching repositories from {ORG} via gh CLI...")
    cmd = ["gh", "repo", "list", ORG, "--limit", "1000", "--json", "name,sshUrl,description"]
    output = run_command(cmd)
    if not output:
        return []
    try:
        return json.loads(output)
    except json.JSONDecodeError:
        return []

def get_submodules() -> Dict[str, str]:
    """Returns a mapping of repo_name -> relative_path for all submodules."""
    submodules = {}
    gitmodules_path = os.path.join(REPO_ROOT, ".gitmodules")
    if not os.path.exists(gitmodules_path):
        return {}

    try:
        # Get all submodule paths and their URLs
        output = run_command(["git", "config", "--file", ".gitmodules", "--get-regexp", "submodule\..+\.path"])
        paths_lines = output.splitlines()
        
        output_url = run_command(["git", "config", "--file", ".gitmodules", "--get-regexp", "submodule\..+\.url"])
        urls_lines = output_url.splitlines()
        
        # Build path map and url map to align them
        path_map = {}
        for line in paths_lines:
            if not line: continue
            parts = line.split(" ")
            sub_name = parts[0].split(".")[1]
            path_map[sub_name] = parts[1]
            
        for line in urls_lines:
            if not line: continue
            parts = line.split(" ")
            sub_name = parts[0].split(".")[1]
            if sub_name in path_map:
                url = parts[1]
                repo_name = os.path.basename(url).replace(".git", "")
                submodules[repo_name] = path_map[sub_name]
    except Exception as e:
        print(f"Warning: Could not parse .gitmodules: {e}")
    
    return submodules

# --- Core Actions ---

def process_repo(repo: Dict, submodules: Dict[str, str], action: str, dry_run: bool):
    name = repo["name"]
    ssh_url = repo["sshUrl"]
    
    if name == PLATFORM_REPO:
        return

    # Determine target directory
    if name in submodules:
        target_path = os.path.join(REPO_ROOT, submodules[name])
        is_submodule = True
    else:
        target_path = os.path.join(SIBLING_DIR, name)
        is_submodule = False

    exists = os.path.exists(target_path)

    if exists:
        if action in ["pull", "both"]:
            print(f"🔄 Updating {name} {'(submodule)' if is_submodule else '(sibling)'}...")
            if not dry_run:
                if is_submodule:
                    run_command(["git", "submodule", "update", "--init", submodules[name]])
                else:
                    run_command(["git", "pull", "--ff-only"], cwd=target_path)
    else:
        if action in ["clone", "both"]:
            print(f"📦 Cloning {name} {'(submodule)' if is_submodule else '(sibling)'}...")
            if not dry_run:
                if is_submodule:
                    if is_submodule:
                        run_command(["git", "submodule", "update", "--init", submodules[name]])
                    else:
                        run_command(["git", "clone", ssh_url, target_path], cwd=SIBLING_DIR)
                else:
                    run_command(["git", "clone", ssh_url, target_path], cwd=SIBLING_DIR)

# --- Interactive CLI ---

def main():
    parser = argparse.ArgumentParser(description="Pull/Clone all Deepiri repositories.")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done without doing it.")
    parser.add_argument("--action", choices=["clone", "pull", "both"], default="both", help="Action to perform.")
    parser.add_argument("--filter", type=str, help="Filter repositories by name.")
    args = parser.parse_args()

    check_auth()
    
    all_repos = fetch_org_repos()
    if not all_repos:
        print("No repositories found.")
        return

    submodules = get_submodules()
    
    # Interactive Filtering
    print(f"\nFound {len(all_repos)} repositories in {ORG}.")
    print("\nHow would you like to filter?")
    print("1. All Repositories")
    print("2. Only Submodules")
    print("3. Only Siblings (External)")
    print("4. Custom Filter (Regex/String)")
    
    choice = input("\nChoice [1]: ").strip() or "1"
    
    filtered_repos = []
    if choice == "1":
        filtered_repos = all_repos
    elif choice == "2":
        filtered_repos = [r for r in all_repos if r["name"] in submodules]
    elif choice == "3":
        filtered_repos = [r for r in all_repos if r["name"] not in submodules]
    elif choice == "4":
        pattern = input("Enter filter pattern: ").strip()
        filtered_repos = [r for r in all_repos if pattern in r["name"]]
    else:
        print("Invalid choice. Defaulting to all.")
        filtered_repos = all_repos

    # Filter out platform itself if it's in the list
    filtered_repos = [r for r in filtered_repos if r["name"] != PLATFORM_REPO]

    if not filtered_repos:
        print("No repositories match the filter.")
        return

    print(f"\nSelected {len(filtered_repos)} repositories.")
    confirm = input("Proceed? [Y/n]: ").strip().lower() or "y"
    if confirm != "y":
        print("Aborted.")
        return

    # Execution
    with ThreadPoolExecutor(max_workers=5) as executor:
        for repo in filtered_repos:
            executor.submit(process_repo, repo, submodules, args.action, args.dry_run)

    print("\n✅ Done!")

if __name__ == "__main__":
    main()
