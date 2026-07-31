"""sdk-greeter entry module: the gateway app.

The interesting part of this example is deploy.jac, which ships this app to
Kubernetes through the programmatic SDK instead of `jac start --scale`.
"""

def:pub ping -> dict {
    return {"ok": True, "app": "sdk-greeter"};
}
