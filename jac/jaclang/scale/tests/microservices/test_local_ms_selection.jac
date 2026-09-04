"""Which topology `jac run` picks for a project that declares service routes.

A web-app declares `[scale.microservices.routes]` for the cut it wants when it
is deployed. Locally, `jac run` on that project is a dev loop: the vite dev
server with HMR, one process. Local microservice mode is the other thing you
can ask for, and asking is explicit: `jac run --ms`, or
`[scale.microservices] enabled = true` in jac.toml. `jac run --serve` (no dev
client) keeps the old default: routes declared means the gateway topology.
"""

import from jaclang.scale.runtime.routing { app_service_name, should_enter_local_ms }


test "a dev web-app run stays single-process even with routes declared" {
    assert not should_enter_local_ms(
        enabled=None,
        is_sv_sibling=False,
        scale_flag=False,
        has_services=True,
        ms_requested=None,
        dev_client=True
    ) , (
        "`jac run` on a web-app is the dev loop (vite + HMR); declaring the "
        "deployed service cut must not take the dev server away"
    );
}


test "--ms asks for the gateway topology, dev client or not" {
    assert should_enter_local_ms(
        enabled=None,
        is_sv_sibling=False,
        scale_flag=False,
        has_services=True,
        ms_requested=True,
        dev_client=True
    );
    assert should_enter_local_ms(
        enabled=None,
        is_sv_sibling=False,
        scale_flag=False,
        has_services=True,
        ms_requested=True,
        dev_client=False
    );
}


test "--no-ms keeps a plain serve single-process" {
    assert not should_enter_local_ms(
        enabled=None,
        is_sv_sibling=False,
        scale_flag=False,
        has_services=True,
        ms_requested=False,
        dev_client=False
    );
}


test "a plain --serve with routes still gets the gateway" {
    assert should_enter_local_ms(
        enabled=None,
        is_sv_sibling=False,
        scale_flag=False,
        has_services=True,
        ms_requested=None,
        dev_client=False
    ) , "deployed-shaped serving is unchanged: routes declared means gateway";
}


test "the config knob decides when the command line says nothing" {
    assert should_enter_local_ms(
        enabled=True,
        is_sv_sibling=False,
        scale_flag=False,
        has_services=True,
        ms_requested=None,
        dev_client=True
    ) , "[scale.microservices] enabled = true asks for the gateway in dev too";
    assert not should_enter_local_ms(
        enabled=False,
        is_sv_sibling=False,
        scale_flag=False,
        has_services=True,
        ms_requested=None,
        dev_client=False
    ) , "enabled = false opts out of local microservice mode";
}


test "an explicit flag outranks the config knob" {
    assert should_enter_local_ms(
        enabled=False,
        is_sv_sibling=False,
        scale_flag=False,
        has_services=True,
        ms_requested=True,
        dev_client=True
    );
    assert not should_enter_local_ms(
        enabled=True,
        is_sv_sibling=False,
        scale_flag=False,
        has_services=True,
        ms_requested=False,
        dev_client=False
    );
}


test "a service sibling or an already-scaled runtime never re-enters" {
    assert not should_enter_local_ms(
        enabled=True,
        is_sv_sibling=True,
        scale_flag=False,
        has_services=True,
        ms_requested=True,
        dev_client=False
    );
    assert not should_enter_local_ms(
        enabled=True,
        is_sv_sibling=False,
        scale_flag=True,
        has_services=True,
        ms_requested=True,
        dev_client=False
    );
}


test "asking for microservice mode without services is not microservice mode" {
    assert not should_enter_local_ms(
        enabled=True,
        is_sv_sibling=False,
        scale_flag=False,
        has_services=False,
        ms_requested=True,
        dev_client=False
    ) , "there is nothing to route; the caller reports it instead of serving";
}


test "the app service is the one that answers at the project root" {
    assert app_service_name({"main": "/__main__", "scoring": "/scoring"}) == "main";
    assert app_service_name({"api": "/", "scoring": "/scoring"}) == "api";
    assert app_service_name({"scoring": "/scoring"}) == "" , (
        "a fleet with no root service has no app to fall back to"
    );
}


test "jac run declares the --ms flag" {
    import from jaclang.cli.commands.execution { SPEC_RUN }
    names = [arg.name for arg in SPEC_RUN.args];
    assert "ms" in names , (
        f"`jac run --ms` is how a web-app asks for local microservice mode; "
        f"got {names}"
    );
}
