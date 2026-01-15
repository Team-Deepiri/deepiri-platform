"""
Validation middleware for Synapse

This package provides middleware for validating events before publishing.
"""

from .validation import ValidationMiddleware

__all__ = ['ValidationMiddleware']
