Overview
--------
This document shows how to build the `deepiri-platform-services` test image and run
the local `test_event_models.py` file inside Docker (no virtualenv required).

Build the image (from repository root)
-------------------------------------

```bash
docker build -f platform-services/shared/deepiri-synapse/Dockerfile -t deepiri-platform-services:dev .
```

Run the single test file (one-liner)
----------------------------------

```bash
docker run --rm -v "$PWD":/workspace -w /workspace \
  -e PYTHONPATH=./platform-services/shared/deepiri-synapse/app/deepiri-modelkit:./platform-services/shared:./ \
  deepiri-platform-services:dev bash -lc "python platform-services/shared/deepiri-synapse/tests/test_event_models.py"
```

If the image does not include dev/test packages, install them first inside the container:

```bash
docker run --rm -v "$PWD":/workspace -w /workspace \
  -e PYTHONPATH=./platform-services/shared/deepiri-synapse/app/deepiri-modelkit:./platform-services/shared:./ \
  deepiri-platform-services:dev bash -lc "pip install -r requirements.txt && python platform-services/shared/deepiri-synapse/tests/test_event_models.py"
```

Interactive shell (optional)
---------------------------

Start an interactive shell in the container to run ad-hoc commands:

```bash
docker run --rm -it -v "$PWD":/workspace -w /workspace \
  -e PYTHONPATH=./platform-services/shared/deepiri-synapse/app/deepiri-modelkit:./platform-services/shared:./ \
  deepiri-platform-services:dev bash
```

Interpretation of results
-------------------------

- Success: the script exits with code `0` and prints `OK` / `Ran X tests` — all tests passed.
- Failure: Python prints tracebacks and failing assertions. The top-most frame inside your repo shows
  the failing assertion and is the best place to start debugging.

Quick troubleshooting
---------------------

- Import errors (`ModuleNotFoundError`): ensure `PYTHONPATH` includes `platform-services/shared` and the
  local `deepiri_modelkit` path (examples above).
- Missing packages: run the `pip install -r requirements.txt` variant shown above.
- Docker build `COPY` errors: run the `docker build` command from the repository root so the Dockerfile's
  `COPY` paths are available.