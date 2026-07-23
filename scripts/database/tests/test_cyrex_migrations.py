from __future__ import annotations

import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "run-cyrex-migrations.py"
MIGRATION_DIRECTORY = Path(__file__).parents[1] / "cyrex"


def load_runner_module():
    spec = importlib.util.spec_from_file_location("cyrex_migration_runner", SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


runner_module = load_runner_module()


class CyrexMigrationTests(unittest.TestCase):
    def test_runner_orders_records_and_skips_migrations(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            (directory / "020_second.sql").write_text("SELECT 2;", encoding="utf-8")
            (directory / "001_first.sql").write_text("SELECT 1;", encoding="utf-8")

            applied: dict[int, tuple[str, str]] = {}
            executed_files: list[str] = []

            def execute(*, sql=None, file=None):
                if file is not None:
                    executed_files.append(file.name)
                    return ""
                if sql and sql.startswith("SELECT version"):
                    return "\n".join(
                        f"{version}|{name}|{checksum}"
                        for version, (name, checksum) in sorted(applied.items())
                    )
                if sql and sql.startswith("INSERT INTO"):
                    version = int(sql.split("VALUES ", 1)[1].split(",", 1)[0].strip("("))
                    name = sql.split("VALUES ", 1)[1].split(", '", 1)[1].split("'", 1)[0]
                    checksum = sql.rsplit("'", 2)[1]
                    applied[version] = (name, checksum)
                return ""

            migration_runner = runner_module.MigrationRunner(directory, execute)
            self.assertEqual(migration_runner.run(), [1, 20])
            self.assertEqual(executed_files, ["001_first.sql", "020_second.sql"])
            self.assertEqual(migration_runner.run(), [])
            self.assertEqual(executed_files, ["001_first.sql", "020_second.sql"])

        migrations = runner_module.discover_migrations(MIGRATION_DIRECTORY)
        self.assertEqual(
            [(migration.version, migration.name) for migration in migrations],
            [
                (1, "schema_meta"),
                (2, "producer_registry_seed"),
                (10, "documents"),
                (20, "artifacts"),
                (30, "pipeline"),
                (70, "reckoning"),
                (80, "pressure"),
                (110, "learning"),
                (120, "helox_bridge"),
            ],
        )

    @unittest.skipUnless(
        os.getenv("CYREX_MIGRATION_SMOKE_TEST") == "1",
        "Set CYREX_MIGRATION_SMOKE_TEST=1 to run the PostgreSQL smoke test",
    )
    def test_postgres_smoke_fresh_and_existing(self) -> None:
        if shutil.which("psql") is None:
            self.skipTest("psql is not installed")

        host = os.getenv("POSTGRES_HOST", "localhost")
        port = os.getenv("POSTGRES_PORT", "5434")
        database = os.getenv("POSTGRES_DB", "cyrex_db")
        user = os.getenv("POSTGRES_USER", "deepiri_cyrex")
        password = os.getenv("POSTGRES_PASSWORD", "deepiripassword")
        environment = {**os.environ, "PGPASSWORD": password}

        command = [
            "psql", "--no-psqlrc", "--set", "ON_ERROR_STOP=1",
            "--host", host, "--port", port, "--username", user,
            "--dbname", database,
        ]

        subprocess.run(
            command + ["--command", "CREATE SCHEMA IF NOT EXISTS cyrex;"],
            env=environment,
            check=True,
        )
        subprocess.run(
            [
                sys.executable, str(SCRIPT), "--directory", str(MIGRATION_DIRECTORY),
                "--host", host, "--port", port, "--database", database,
                "--user", user, "--password", password,
            ],
            check=True,
        )
        subprocess.run(
            [
                sys.executable, str(SCRIPT), "--directory", str(MIGRATION_DIRECTORY),
                "--host", host, "--port", port, "--database", database,
                "--user", user, "--password", password,
            ],
            check=True,
        )

        result = subprocess.run(
            command + [
                "--command",
                "SELECT version, name FROM cyrex.schema_migrations ORDER BY version; "
                "SELECT producer_id, schema_version, jsonb_array_length(allowed_sinks) "
                "FROM cyrex.producer_registry ORDER BY producer_id;",
            ],
            env=environment,
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertIn("1|schema_meta", result.stdout)
        self.assertIn("2|producer_registry_seed", result.stdout)
        for migration in (
            "10|documents",
            "20|artifacts",
            "30|pipeline",
            "70|reckoning",
            "80|pressure",
            "110|learning",
            "120|helox_bridge",
        ):
            self.assertIn(migration, result.stdout)
        for producer in (
            "artifact_store",
            "correction_writer",
            "document_ingest",
            "orchestrator",
            "parse_stage",
            "pressure_projector",
            "reckoning_updater",
            "training_emitter",
        ):
            self.assertIn(producer, result.stdout)


if __name__ == "__main__":
    unittest.main()
