"""Greeter service: the single microservice of the SDK deploy example.

GREETING_PREFIX arrives through DeploySpec.env (plain env var) and
GREETER_SECRET through DeploySpec.secrets (Kubernetes Secret), so a call to
greet proves both in-memory channels reached the pod.
"""
import os;

def:pub greet(name: str = "world") -> dict {
    prefix = os.environ.get("GREETING_PREFIX", "hello");
    return {
        "message": f"{prefix}, {name}!",
        "secret_present": bool(os.environ.get("GREETER_SECRET"))
    };
}
