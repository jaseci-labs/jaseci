# Product-path facade for staged ``jac-py/Modules/_heapqmodule.jac``.
# Libtest stdlib shims delegate to host ``heapq`` (algorithm smoke parity).
::py::
import heapq as _host_heapq


def _p2_heappush(heap: list, item) -> None:
    _host_heapq.heappush(heap, item)


def _p2_heappop(heap: list):
    return _host_heapq.heappop(heap)


def _p2_heapify(heap: list) -> None:
    _host_heapq.heapify(heap)
::py::
