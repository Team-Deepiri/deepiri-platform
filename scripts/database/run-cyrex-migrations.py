#!/usr/bin/env python3
"""Apply numbered Cyrex PostgreSQL migrations in order.

Production rules:
- Migrations are hand-written, immutable after apply (checksum-enforced).
- Each pending migration runs in a single transaction with its ledger insert.
- Schema/extensions live in SQL (001); the runner only ensures the ledger
  table exists so it can query applied versions on a fresh database.
- Uses ``psql`` so the platform repo does not take a Python DB dependency.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Sequence


MIGRATION_PATTERN = re.compile(r"^(?P<version>\d+)_(?P<name>[A-Za-z0-9][A-Za-z0-9_.-]*)\.sql$")
DEFAULT_DIRECTORY = Path(__file__).resolve().parent / "cyrex"


@dataclass(frozen=True)
class Migration:
    version: int
    name: str
    path: Path

    @property
    def checksum(self) -> str:
        return hashlib.sha256(self.path.read_bytes()).hexdigest()


def discover_migrations(directory: Path) -> list[Migration]:
    """Discover and validate numbered SQL files."""
    migrations: list[Migration] = []
    seen_versions: set[int] = set()

    for path in directory.glob("*.sql"):
        match = MIGRATION_PATTERN.match(path.name)
        if not match:
            raise ValueError(
                f"Migration file must use '<number>_<name>.sql': {path.name}"
            )

        version = int(match.group("version"))
        if version in seen_versions:
            raise ValueError(f"Duplicate migration version: {version}")
        seen_versions.add(version)
        migrations.append(Migration(version, match.group("name"), path))

    if not migrations:
        raise ValueError(f"No migration files found in {directory}")

    return sorted(migrations, key=lambda migration: migration.version)


def sql_literal(value: str) -> str:
    """Escape a string as a PostgreSQL string literal."""
    return "'" + value.replace("'", "''") + "'"


def _psql_base(args: argparse.Namespace) -> list[str]:
    return [
        args.psql,
        "--no-psqlrc",
        "--set",
        "ON_ERROR_STOP=1",
        "--host",
        args.host,
        "--port",
        str(args.port),
        "--username",
        args.user,
        "--dbname",
        args.database,
        "--tuples-only",
        "--no-align",
    ]


def build_executor(args: argparse.Namespace) -> Callable[..., str]:
    environment = os.environ.copy()
    if args.password:
        environment["PGPASSWORD"] = args.password

    def execute(
        *,
        sql: str | None = None,
        file: Path | None = None,
        single_transaction: bool = False,
    ) -> str:
        command = _psql_base(args)
        if single_transaction:
            command.append("--single-transaction")
        if file is not None and sql is not None:
            command.extend(["--file", str(file), "--command", sql])
        elif sql is not None:
            command.extend(["--command", sql])
        elif file is not None:
            command.extend(["--file", str(file)])
        else:
            raise ValueError("Either sql or file is required")

        result = subprocess.run(
            command,
            env=environment,
            check=True,
            capture_output=True,
            text=True,
        )
        return result.stdout

    return execute


class MigrationRunner:
    def __init__(
        self,
        directory: Path,
        execute: Callable[..., str],
    ) -> None:
        self.directory = directory
        self.execute = execute

    def bootstrap_tracking(self) -> None:
        """Ensure the ledger exists so applied versions can be queried.

        Extensions and full schema ownership live in ``001_schema_meta.sql``.
        This bootstrap is only a safety net for fresh databases.
        """
        self.execute(
            sql="""
            CREATE SCHEMA IF NOT EXISTS cyrex;
            CREATE TABLE IF NOT EXISTS cyrex.schema_migrations (
                version INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                checksum TEXT NOT NULL,
                applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
            """
        )

    def applied_migrations(self) -> dict[int, tuple[str, str]]:
        output = self.execute(
            sql=(
                "SELECT version, name, checksum "
                "FROM cyrex.schema_migrations ORDER BY version;"
            )
        )
        applied: dict[int, tuple[str, str]] = {}
        for line in output.splitlines():
            if not line.strip():
                continue
            version, name, checksum = line.split("|", 2)
            applied[int(version)] = (name, checksum)
        return applied

    def run(self) -> list[int]:
        migrations = discover_migrations(self.directory)
        self.bootstrap_tracking()
        applied = self.applied_migrations()
        newly_applied: list[int] = []

        for migration in migrations:
            existing = applied.get(migration.version)
            if existing:
                existing_name, existing_checksum = existing
                if existing_name != migration.name or existing_checksum != migration.checksum:
                    raise RuntimeError(
                        f"Migration {migration.version} changed after being applied"
                    )
                continue

            ledger_insert = (
                "INSERT INTO cyrex.schema_migrations "
                "(version, name, checksum) VALUES "
                f"({migration.version}, {sql_literal(migration.name)}, "
                f"{sql_literal(migration.checksum)});"
            )
            # File + ledger insert share one transaction so a crash cannot
            # leave DDL applied without a ledger row (or the reverse).
            self.execute(
                file=migration.path,
                sql=ledger_insert,
                single_transaction=True,
            )
            newly_applied.append(migration.version)

        return newly_applied


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=DEFAULT_DIRECTORY)
    parser.add_argument("--psql", default="psql")
    parser.add_argument("--host", default=os.getenv("POSTGRES_HOST", "localhost"))
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.getenv("POSTGRES_PORT", os.getenv("POSTGRES_CYREX_PORT", "5432"))),
    )
    parser.add_argument(
        "--database",
        default=os.getenv("POSTGRES_DB", os.getenv("POSTGRES_CYREX_DB", "cyrex_db")),
    )
    parser.add_argument(
        "--user",
        default=os.getenv("POSTGRES_USER", os.getenv("POSTGRES_CYREX_USER", "deepiri_cyrex")),
    )
    parser.add_argument(
        "--password",
        default=os.getenv(
            "POSTGRES_PASSWORD",
            os.getenv("POSTGRES_CYREX_PASSWORD", ""),
        ),
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    runner = MigrationRunner(args.directory, build_executor(args))
    applied = runner.run()
    if applied:
        print(f"Applied Cyrex migrations: {', '.join(map(str, applied))}")
    else:
        print("Cyrex migrations are already up to date")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
