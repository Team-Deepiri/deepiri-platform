#!/usr/bin/env python3
"""Deepiri team env controller — reads teams/*.yml and runs pull/build/start/stop."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML required. Run: pip3 install --user pyyaml", file=sys.stderr)
    sys.exit(1)

REPO_ROOT = Path(__file__).resolve().parent.parent
TEAMS_DIR = Path(__file__).resolve().parent
COMPOSE_FILE = "docker-compose.dev.yml"
ALL_SERVICES_FILE = TEAMS_DIR / "all-services.yml"
ALL_SUBMODULES_FILE = TEAMS_DIR / "all-submodules.yml"

# Compose service -> Dockerfile path (for require_dockerfile start checks)
DOCKERFILE_HINTS = {
    "api-gateway": "platform-services/backend/deepiri-api-gateway/Dockerfile",
    "auth-service": "platform-services/backend/deepiri-auth-service/Dockerfile",
    "external-bridge-service": "platform-services/backend/deepiri-external-bridge-service/Dockerfile",
    "language-intelligence-service": "platform-services/backend/deepiri-language-intelligence-service/Dockerfile",
    "synapse": "platform-services/shared/deepiri-synapse/Dockerfile",
    "synapse-sugar-glider": "platform-services/shared/deepiri-sugar-glider/Dockerfile",
    "frontend-dev": "deepiri-web-frontend/Dockerfile",
    "cyrex": "diri-cyrex/Dockerfile",
    "speech": "platform-services/backend/deepiri-speech/Dockerfile",
    "deepiri-prismpipe": "platform-services/shared/deepiri-prismpipe/Dockerfile",
}


def load_yaml(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    if not isinstance(data, dict):
        raise SystemExit(f"Invalid YAML (expected mapping): {path}")
    return data


def list_team_ids() -> list[str]:
    skip = {"all-services", "all-submodules"}
    return sorted(p.stem for p in TEAMS_DIR.glob("*.yml") if p.stem not in skip)


def resolve_team_path(team: str) -> Path:
    aliases = {
        "ai": "ai-team",
        "backend": "backend-team",
        "frontend": "frontend-team",
        "infrastructure": "infrastructure-team",
        "infra": "infrastructure-team",
        "ml": "ml-team",
        "platform": "platform-engineers",
        "platform-engineers": "platform-engineers",
        # Monolithic QA stack (legacy). Prefer QA tiers from PR #301.
        "qa": "qa-team",
        "all": "platform-engineers",
        # QA capacity tiers → eng team YAMLs (setup-deepiri-dev.sh select_qa_tier)
        "qa-tier-1": "frontend-team",
        "qa-tier-2": "backend-team",
        "qa-tier-3": "ai-team",
        "qa:1": "frontend-team",
        "qa:2": "backend-team",
        "qa:3": "ai-team",
        "qa1": "frontend-team",
        "qa2": "backend-team",
        "qa3": "ai-team",
    }
    name = aliases.get(team, team)
    path = TEAMS_DIR / f"{name}.yml"
    if not path.exists():
        known = ", ".join(sorted({*list_team_ids(), *aliases}))
        raise SystemExit(f"Unknown team '{team}'. Known: {known}")
    return path


def load_team(team: str) -> dict[str, Any]:
    return load_yaml(resolve_team_path(team))


def resolve_services(cfg: dict[str, Any]) -> list[str]:
    services = cfg.get("services", [])
    if services == "all" or services is True:
        catalog = load_yaml(ALL_SERVICES_FILE)
        return list(catalog.get("services") or [])
    if not isinstance(services, list):
        raise SystemExit(f"services must be a list or 'all', got {type(services)}")
    disabled = set(cfg.get("disabled_services") or [])
    return [s for s in services if s not in disabled and not str(s).startswith("#")]


def resolve_submodules(cfg: dict[str, Any]) -> list[str]:
    subs = cfg.get("submodules", [])
    if subs == "all" or subs is True:
        catalog = load_yaml(ALL_SUBMODULES_FILE)
        return [entry["path"] for entry in catalog.get("submodules") or []]
    if not isinstance(subs, list):
        raise SystemExit(f"submodules must be a list or 'all', got {type(subs)}")
    out: list[str] = []
    for item in subs:
        if isinstance(item, str):
            out.append(item)
        elif isinstance(item, dict) and "path" in item:
            out.append(item["path"])
    return out


def pull_only_set(cfg: dict[str, Any]) -> set[str]:
    build = cfg.get("build") or {}
    if "pull_only" in build:
        return set(build["pull_only"] or [])
    catalog = load_yaml(ALL_SERVICES_FILE)
    return set(catalog.get("pull_only") or [])


def run(cmd: list[str], *, check: bool = True, cwd: Path | None = None) -> int:
    print(f"+ {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=str(cwd or REPO_ROOT))
    if check and result.returncode != 0:
        raise SystemExit(result.returncode)
    return result.returncode


def ensure_suite_images() -> None:
    suite_dir = Path(os.environ.get("DEEPIRI_SUITE_CONTEXT", str(REPO_ROOT / "deepiri-suite")))
    print("Ensuring deepiri-suite base images...")
    all_ok = True
    for base, tag in (
        ("node:18-alpine", "18-alpine"),
        ("node:18-slim", "18-slim"),
        ("node:20-alpine", "20-alpine"),
    ):
        img = f"ghcr.io/team-deepiri/deepiri-suite:{tag}"
        if subprocess.run(
            ["docker", "image", "inspect", img],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode == 0:
            print(f"   ok {img} (cached)")
            continue
        print(f"   Pulling {img} from GHCR...")
        if subprocess.run(
            ["docker", "pull", img],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode == 0:
            print(f"   ok {img} (pulled)")
            continue
        print(f"   GHCR pull failed -- building locally (BASE_IMAGE={base})")
        if not (suite_dir / "Dockerfile").is_file():
            print(f"   deepiri-suite not found at {suite_dir}")
            print("      Run: ./setup-deepiri-dev.sh pull <team>")
            all_ok = False
            continue
        if run(
            ["docker", "build", "--build-arg", f"BASE_IMAGE={base}", "-t", img, str(suite_dir)],
            check=False,
        ) == 0:
            print(f"   ok {img} (built locally)")
        else:
            print(f"   Failed to build {img} locally")
            all_ok = False
    if not all_ok:
        raise SystemExit(1)


def detect_backend() -> str:
    if shutil.which("nvidia-smi"):
        return "cuda"
    if sys.platform == "darwin":
        return "mps"
    return "other"


def check_submodule(path: Path) -> bool:
    if not path.is_dir():
        return False
    git_marker = path / ".git"
    if not git_marker.exists():
        return False
    return (
        subprocess.run(
            ["git", "rev-parse", "--git-dir"],
            cwd=str(path),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        == 0
    )


def cleanup_invalid_submodule(rel: str) -> None:
    path = REPO_ROOT / rel
    if path.is_dir() and not check_submodule(path):
        print(f"    Directory exists but is not a valid submodule. Cleaning {rel}...")
        shutil.rmtree(path)


def ensure_submodule_on_main(rel: str) -> None:
    path = REPO_ROOT / rel
    if not path.is_dir():
        return
    subprocess.run(["git", "fetch", "origin"], cwd=str(path), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    branch = "main"
    has_main = (
        subprocess.run(
            ["git", "show-ref", "--verify", "--quiet", "refs/remotes/origin/main"],
            cwd=str(path),
        ).returncode
        == 0
    )
    has_master = (
        subprocess.run(
            ["git", "show-ref", "--verify", "--quiet", "refs/remotes/origin/master"],
            cwd=str(path),
        ).returncode
        == 0
    )
    if not has_main and has_master:
        branch = "master"
    elif not has_main and not has_master:
        print(f"    No main/master for {rel}, skipping checkout")
        return

    detached = (
        subprocess.run(
            ["git", "symbolic-ref", "-q", "HEAD"],
            cwd=str(path),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        != 0
    )
    if detached:
        subprocess.run(
            ["git", "checkout", "-B", branch, f"origin/{branch}"],
            cwd=str(path),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    else:
        cur = subprocess.run(
            ["git", "symbolic-ref", "--short", "HEAD"],
            cwd=str(path),
            capture_output=True,
            text=True,
        )
        if cur.stdout.strip() != branch:
            subprocess.run(
                ["git", "checkout", branch],
                cwd=str(path),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
    subprocess.run(
        ["git", "branch", f"--set-upstream-to=origin/{branch}", branch],
        cwd=str(path),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    subprocess.run(
        ["git", "pull", "origin", branch],
        cwd=str(path),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def cmd_pull(team: str, cfg: dict[str, Any]) -> None:
    display = cfg.get("display", team)
    print(f"{display} — pulling submodules")
    if not (REPO_ROOT / ".git").exists():
        raise SystemExit(f"Not a git repo: {REPO_ROOT}")

    os.chdir(REPO_ROOT)
    subprocess.run(["git", "pull", "origin", "main"], check=False)

    recursive = bool((cfg.get("pull") or {}).get("recursive", True))
    checkout_main = bool((cfg.get("pull") or {}).get("checkout_main", True))
    run_hooks = bool((cfg.get("pull") or {}).get("setup_hooks", True))

    if (cfg.get("submodules") == "all") or (cfg.get("pull") or {}).get("all_recursive"):
        run(["git", "submodule", "update", "--init", "--recursive"])
        # Still ensure suite + logger explicitly for clarity
        for sm in resolve_submodules({**cfg, "submodules": "all"}):
            print(f"  ready: {sm}")
    else:
        for sm in resolve_submodules(cfg):
            print(f"  Initializing {sm}...")
            cleanup_invalid_submodule(sm)
            parent = REPO_ROOT / sm
            parent.parent.mkdir(parents=True, exist_ok=True)
            init_cmd = ["git", "submodule", "update", "--init"]
            if recursive:
                init_cmd.append("--recursive")
            init_cmd.append(sm)
            rc = run(init_cmd, check=False)
            if rc != 0 or not check_submodule(REPO_ROOT / sm):
                required = sm not in set((cfg.get("pull") or {}).get("optional") or [])
                msg = f"    Failed to init {sm}"
                if required:
                    print(msg)
                    raise SystemExit(1)
                print(f"{msg} (optional)")
                continue
            if checkout_main:
                run(["git", "submodule", "update", "--remote", sm], check=False)
                ensure_submodule_on_main(sm)
            print(f"    ok {sm}")

    if run_hooks:
        hooks = REPO_ROOT / "setup-hooks.sh"
        if hooks.is_file():
            run(["bash", str(hooks)], check=False)
        # Per-team hook script if present
        team_hooks = REPO_ROOT / "team_submodule_commands" / cfg.get("id", team) / "setup-hooks.sh"
        if team_hooks.is_file():
            run(["bash", str(team_hooks)], check=False)

    print(f"Submodules ready for {display}")


def cmd_build(team: str, cfg: dict[str, Any]) -> None:
    display = cfg.get("display", team)
    build = cfg.get("build") or {}
    services = resolve_services(cfg)

    buildkit = bool(build.get("buildkit", False))
    os.environ["DOCKER_BUILDKIT"] = "1" if buildkit else "0"
    os.environ["COMPOSE_DOCKER_CLI_BUILD"] = "1" if buildkit else "0"

    if build.get("ensure_suite_images", True):
        ensure_suite_images()

    print(f"Building {display} services...")
    if not services:
        print("No services listed")
        return

    pull_only = pull_only_set(cfg)
    for img in build.get("docker_pull") or []:
        print(f"Pulling {img}...")
        run(["docker", "pull", img], check=False)

    buildable = [s for s in services if s not in pull_only]
    if not buildable and cfg.get("services") != "all":
        print("Nothing to build (all services are pull-only)")
        return

    sequential = bool(build.get("sequential", False))
    if cfg.get("services") == "all":
        # Build whatever compose reports (skip pure image services that fail build no-op)
        out = subprocess.check_output(
            ["docker", "compose", "-f", COMPOSE_FILE, "config", "--services"],
            cwd=str(REPO_ROOT),
            text=True,
        )
        buildable = [s for s in out.split() if s not in pull_only]

    failed: list[str] = []
    if sequential:
        for svc in buildable:
            print(f"-- Building {svc} --")
            if run(["docker", "compose", "-f", COMPOSE_FILE, "build", svc], check=False) != 0:
                failed.append(svc)
                print(f"FAILED {svc}")
    else:
        if buildable:
            if run(["docker", "compose", "-f", COMPOSE_FILE, "build", *buildable], check=False) != 0:
                failed.extend(buildable)

    if failed:
        print(f"Failed services: {' '.join(failed)}")
        raise SystemExit(1)
    print(f"{display} services built successfully")


def filter_start_services(cfg: dict[str, Any], services: list[str]) -> list[str]:
    start = cfg.get("start") or {}
    out = list(services)

    backend = detect_backend()
    print(f"Detected backend: {backend}")
    exclude = start.get("exclude_on_mps") or []
    if backend == "mps" and exclude:
        print(f"MPS — excluding: {', '.join(exclude)}")
        out = [s for s in out if s not in exclude]

    require_df = set(start.get("require_dockerfile") or [])
    filtered: list[str] = []
    for s in out:
        if s in require_df:
            hint = DOCKERFILE_HINTS.get(s)
            if hint and not (REPO_ROOT / hint).is_file():
                print(f"Skipping {s} (Dockerfile missing: {hint})")
                continue
        filtered.append(s)

    optional = set(start.get("optional") or [])
    final: list[str] = []
    for s in filtered:
        if s in optional:
            img_guess = f"deepiri-dev-{s}:latest"
            if subprocess.run(
                ["docker", "image", "inspect", img_guess],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            ).returncode != 0:
                print(f"Skipping optional {s} (image not found)")
                continue
        final.append(s)
    return final


def cmd_start(team: str, cfg: dict[str, Any]) -> None:
    display = cfg.get("display", team)
    start = cfg.get("start") or {}
    services = resolve_services(cfg)

    if cfg.get("services") == "all":
        print(f"Starting {display} (all compose services)...")
        args = ["docker", "compose", "-f", COMPOSE_FILE, "up", "-d", "--no-build"]
        run(args)
    else:
        services = filter_start_services(cfg, services)
        if not services:
            raise SystemExit("No services to start")
        print(f"Starting {display}: {' '.join(services)}")
        args = ["docker", "compose", "-f", COMPOSE_FILE, "up", "-d", "--no-build"]
        if start.get("no_deps", True):
            args.append("--no-deps")
        # phased start: infra first
        phases = start.get("phases")
        if phases:
            for phase in phases:
                names = [s for s in phase if s in services]
                if not names:
                    continue
                print(f"Phase: {' '.join(names)}")
                p_args = ["docker", "compose", "-f", COMPOSE_FILE, "up", "-d", "--no-build"]
                if start.get("no_deps", True) and phase is not phases[0]:
                    p_args.append("--no-deps")
                run([*p_args, *names])
                wait = int(start.get("phase_wait_seconds") or 0)
                if wait and phase is phases[0]:
                    import time

                    print(f"Waiting {wait}s for infrastructure...")
                    time.sleep(wait)
            # start any remaining not covered by phases
            phased = {s for phase in phases for s in phase}
            rest = [s for s in services if s not in phased]
            if rest:
                r_args = ["docker", "compose", "-f", COMPOSE_FILE, "up", "-d", "--no-build"]
                if start.get("no_deps", True):
                    r_args.append("--no-deps")
                run([*r_args, *rest])
        else:
            run([*args, *services])

    print(f"{display} services started")
    for line in cfg.get("urls") or []:
        # expand simple ${VAR:-default}
        print(os.path.expandvars(line.replace("${API_GATEWAY_PORT:-5100}", os.environ.get("API_GATEWAY_PORT", "5100"))))


def cmd_stop(team: str, cfg: dict[str, Any], *, remove: bool = False) -> None:
    display = cfg.get("display", team)
    services = resolve_services(cfg)
    print(f"Stopping {display}...")
    if cfg.get("services") == "all":
        run(["docker", "compose", "-f", COMPOSE_FILE, "stop"], check=False)
        if remove:
            run(["docker", "compose", "-f", COMPOSE_FILE, "rm", "-f"], check=False)
    else:
        if services:
            run(["docker", "compose", "-f", COMPOSE_FILE, "stop", *services], check=False)
            if remove:
                run(["docker", "compose", "-f", COMPOSE_FILE, "rm", "-f", *services], check=False)
    print(f"{display} services stopped" + (" and removed" if remove else ""))


def cmd_restart(team: str, cfg: dict[str, Any]) -> None:
    cmd_stop(team, cfg, remove=False)
    cmd_start(team, cfg)


def cmd_show(team: str, cfg: dict[str, Any]) -> None:
    print(f"id: {cfg.get('id', team)}")
    print(f"display: {cfg.get('display', team)}")
    services = resolve_services(cfg)
    print(f"services ({len(services)}):")
    for s in services:
        print(f"  - {s}")
    subs = resolve_submodules(cfg)
    print(f"submodules ({len(subs)}):")
    for s in subs:
        print(f"  - {s}")


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="setup-deepiri-dev.sh / teams/team_ctl.py",
        description="Team compose + submodule controller (YAML-driven)",
    )
    p.add_argument(
        "command",
        choices=["pull", "build", "start", "stop", "stop-rm", "restart", "show", "list-teams"],
    )
    p.add_argument("team", nargs="?", help="Team id (ai-team, backend, …)")
    return p


def main(argv: list[str] | None = None) -> None:
    args = build_parser().parse_args(argv)
    if args.command == "list-teams":
        for t in sorted(
            p.stem
            for p in TEAMS_DIR.glob("*.yml")
            if p.name not in ("all-services.yml", "all-submodules.yml")
        ):
            print(t)
        return
    if not args.team:
        raise SystemExit("team argument required (or use list-teams)")
    cfg = load_team(args.team)
    team_id = cfg.get("id") or resolve_team_path(args.team).stem
    cfg.setdefault("id", team_id)

    os.chdir(REPO_ROOT)
    if args.command == "pull":
        cmd_pull(team_id, cfg)
    elif args.command == "build":
        cmd_build(team_id, cfg)
    elif args.command == "start":
        cmd_start(team_id, cfg)
    elif args.command == "stop":
        cmd_stop(team_id, cfg, remove=False)
    elif args.command == "stop-rm":
        cmd_stop(team_id, cfg, remove=True)
    elif args.command == "restart":
        cmd_restart(team_id, cfg)
    elif args.command == "show":
        cmd_show(team_id, cfg)


if __name__ == "__main__":
    main()
