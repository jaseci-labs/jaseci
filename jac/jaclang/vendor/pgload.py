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


def connect(
    user,
    host=None,
    port=5432,
    unix_socket_dir=None,
    database="postgres",
    password=None,
    timeout=None,
    startup_params=None,
):
    """Open a pg8000 native connection from ConnInfo-style fields.

    pg8000 takes the socket *file* (unix_sock), not the directory postgres
    reports; this is the one place that translation lives.
    """
    pg = load_pg8000()
    kwargs = {
        "port": port,
        "database": database,
        "timeout": timeout,
        "startup_params": startup_params,
    }
    if password:
        kwargs["password"] = password
    if unix_socket_dir:
        kwargs["unix_sock"] = os.path.join(unix_socket_dir, f".s.PGSQL.{port}")
    else:
        kwargs["host"] = host or "127.0.0.1"
    return pg.native.Connection(user, **kwargs)
