"""Pinned external artifacts vendored into the jac distribution.

Contents:
- ``typeshed/``: the pinned Python stdlib type stubs the type checker
  resolves stdlib types from. The stubs themselves are fetched at the
  pinned commit (see ``typeshed/PROVENANCE.md``); only PIN /
  TARBALL_SHA256 / LICENSE / PROVENANCE.md are tracked.
- ``pgload.py``: historical name, no longer vendored code -- a thin
  facade mapping ConnInfo-style fields onto jac's own wire client
  (``jaclang.data.pgwire``).

Historically this package also carried vendored Python packages
(pg8000, cattrs) resolved by bare name via a ``sys.path`` insertion;
both the packages and the insertion are gone -- everything here is
imported as ``jaclang.vendor.<name>``.
"""

__all__: list = []
