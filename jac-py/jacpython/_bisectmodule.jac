# Product-path facade for staged ``jac-py/Modules/_bisectmodule.jac``.
# Libtest stdlib shims delegate to host ``bisect`` (algorithm smoke parity).
::py::
import bisect as _host_bisect


def _p2_bisect_right(data: list, item, lo: int = 0, hi=None) -> int:
    if hi is None:
        return _host_bisect.bisect_right(data, item, lo)
    return _host_bisect.bisect_right(data, item, lo, hi)


def _p2_bisect_left(data: list, item, lo: int = 0, hi=None) -> int:
    if hi is None:
        return _host_bisect.bisect_left(data, item, lo)
    return _host_bisect.bisect_left(data, item, lo, hi)


def _p2_insort(data: list, item, lo: int = 0, hi=None) -> None:
    if hi is None:
        _host_bisect.insort(data, item, lo)
    else:
        _host_bisect.insort(data, item, lo, hi)


def _p2_insort_left(data: list, item, lo: int = 0, hi=None) -> None:
    if hi is None:
        _host_bisect.insort_left(data, item, lo)
    else:
        _host_bisect.insort_left(data, item, lo, hi)
::py::
