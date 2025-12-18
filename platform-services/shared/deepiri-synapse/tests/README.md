Docker instructions for running tests (no venv)
=============================================

Problem
-------
The Dockerfile in
`platform-services/shared/deepiri-synapse/Dockerfile` contains `COPY` statements that expect
paths relative to the build context. If you build from the subdirectory, those paths are not
present and the build fails with "not found" errors.

Recommended approach
---------------------
Build using the repository root as the build context and point Docker to the Dockerfile in the
subdirectory. From the repository root run:

```bash
docker build -f platform-services/shared/deepiri-synapse/Dockerfile -t deepiri-platform-services:dev .
```

Why: `COPY` in the Dockerfile is relative to the build context (the final `.`). Using the repo root
ensures paths like `platform-services/...` exist for `COPY` to read.

Quick workaround (if Dockerfile expects top-level `deepiri-modelkit`)
-----------------------------------------------------------------
If the Dockerfile uses `COPY deepiri-modelkit ...` and `deepiri-modelkit` actually lives at
`platform-services/shared/deepiri-modelkit`, create a temporary symlink at the repo root before
building:

```bash
# from repo root
ln -s platform-services/shared/deepiri-modelkit deepiri-modelkit
docker build -f platform-services/shared/deepiri-synapse/Dockerfile -t deepiri-platform-services:dev .
rm deepiri-modelkit
```

Permanent fix (recommended if you maintain the Dockerfile)
--------------------------------------------------------
Edit the Dockerfile so the `COPY` paths match the actual source locations, e.g. change
`COPY deepiri-modelkit /app/deepiri-modelkit` to `COPY platform-services/shared/deepiri-modelkit /app/deepiri-modelkit`.
You can patch it locally with a command like (review before running):

```bash
sed -i 's|COPY deepiri-modelkit |COPY platform-services/shared/deepiri-modelkit |' platform-services/shared/deepiri-synapse/Dockerfile
```

Running tests inside the built image
-----------------------------------
Mount the repo into the container and set `PYTHONPATH` so the tests import local packages:

```bash
docker run --rm \
  -v "$PWD":/workspace \
  -w /workspace \
  -e PYTHONPATH=./platform-services/shared:./ \
  deepiri-platform-services:dev \
  bash -lc "pytest -q platform-services/shared/deepiri-synapse/tests/test_event_models.py"
```

If the image doesn't include development/test dependencies, install them on-the-fly inside the
container:

```bash
docker run --rm -v "$PWD":/workspace -w /workspace deepiri-platform-services:dev \
  bash -lc "pip install -r requirements.txt && pytest -q platform-services/shared/deepiri-synapse/tests/test_event_models.py"
```

Check `.dockerignore`
---------------------
Make sure `.dockerignore` does not exclude the folders you need (e.g. `platform-services` or
`deepiri-modelkit`). Inspect it with:

```bash
cat .dockerignore
```

Notes
-----
- Always run the `docker build` command from the repo root when the Dockerfile contains
  `COPY` lines that reference top-level or sibling directories.
- Creating a temporary symlink is a quick workaround; editing the Dockerfile to match the
  repo layout is the cleaner long-term solution.
