"""Loader for the vendored pure-python Postgres wire driver.

A project-installed pg8000 (any compatible version) always wins; the vendored
copy under vendor/pgdriver is a sys.path fallback so the zero-dependency jac
binary can speak to Postgres out of the box.
"""

import os
import sys


def load_pg8000():
    """Return the pg8000 package, preferring a project-installed one."""
    try:
        import pg8000.native  # noqa: F401
    except ImportError:
        vendor = os.path.join(os.path.dirname(__file__), "pgdriver")
        if vendor not in sys.path:
            sys.path.append(vendor)
        import pg8000.native  # noqa: F401
    import pg8000

    return pg8000
