from __future__ import annotations

import logging
import sys

import structlog

from .processors import deepiri_schema_processor


def init(service_name: str, version: str = "unknown", log_level: str = "INFO") -> None:
    """Initialize Deepiri logger for Python services."""
    logging.basicConfig(
        level=getattr(logging, log_level.upper(), logging.INFO),
        format="%(message)s",
        handlers=[logging.StreamHandler(sys.stdout)],
    )

    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            deepiri_schema_processor,
            structlog.processors.JSONRenderer(),
        ],
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )

    # Ensure all emitted events have service metadata unless overridden at call time.
    structlog.get_logger().bind(service_name=service_name, version=version)
