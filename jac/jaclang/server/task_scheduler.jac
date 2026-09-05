import threading;
import time;
import heapq;
import datetime;
import logging;
import from jaclang.runtime.builtin { ScheduleTrigger }

glob _scheduler_instance: (Scheduler | None) = None,
     logger = logging.getLogger(__name__);

obj ScheduleSpec {
    has date: (str | None) = None,
        interval: (float | None) = None,
        cron: (str | None) = None,
        trigger: ScheduleTrigger = ScheduleTrigger.STATIC;
}

obj ScheduledTask {
    has name: str,
        target: Callable,
        spec: ScheduleSpec,
        is_walker: bool,
        next_run: (datetime.datetime | None) = None,
        last_run: (datetime.datetime | None) = None;
}

"""Fires static `@schedule` tasks on time, once per fleet when leased.

`lease(key, ttl_seconds)` is supplied by the server from the project store;
when it is set, a task fires only in the process that wins the lease for
that tick, so N workers on a host and N pods behind a database agree on one
firing. Without a lease (no store) every process fires, as before."""
obj Scheduler {
    has _tasks: list[ScheduledTask] = [],
        _thread: (threading.Thread | None) = None,
        _running: bool = False,
        _stop_event: (threading.Event | None) = None,
        _done_event: (threading.Event | None) = None,
        dynamic_handler: (Callable | None) = None,
        lease: (Callable[[str, int], bool] | None) = None;

    static def instance -> Scheduler;
    def register(
        name: str, target: Callable, spec: ScheduleSpec, is_walker: bool
    ) -> None;

    def start -> None;
    def start_if_pending -> None;
    def _lease_ttl(spec: ScheduleSpec) -> int;
    def _may_fire(task: ScheduledTask) -> bool;
    def stop -> None;
    def `wait -> None;
    def has_pending -> bool;
    def _run_loop -> None;
    def _pick_up_new_tasks(heap: list[tuple[float, int, ScheduledTask]]) -> None;
    def _compute_next_run(
        spec: ScheduleSpec, now: datetime.datetime
    ) -> (datetime.datetime | None);

    def _compute_date(
        date_str: str, now: datetime.datetime
    ) -> (datetime.datetime | None);

    def _parse_cron_next(cron: str, now: datetime.datetime) -> datetime.datetime;
    def _cron_field_matches(
        field: str, value: int, min_val: int, max_val: int
    ) -> bool;

    def _execute(task: ScheduledTask) -> None;
}
