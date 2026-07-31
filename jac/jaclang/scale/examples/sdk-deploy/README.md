# sdk-deploy: programmatic deploys with the jac-scale SDK

A two-module microservice app (`main.jac` gateway + `greeter.jac` service)
whose deploy is driven by `deploy.jac` through `jaclang.scale.sdk` - the
programmatic equivalent of `jac start main.jac --scale`:

```bash
jac run deploy.jac deploy     # deploy to the current kubeconfig context
jac run deploy.jac status     # structured status
jac run deploy.jac url        # externally reachable URL, if any
jac run deploy.jac destroy    # tear down; never prompts
```

What the driver demonstrates:

- The whole deploy configuration lives on a `DeploySpec` in memory - the
  deploy side never reads `jac.toml`. (The app's own `jac.toml` still
  declares `[scale.microservices.routes]` because the in-cluster gateway
  reads it at runtime; the spec declares the same routes for the deploy.)
- `env` ships plain env vars and `secrets` ships a Kubernetes Secret to
  every service pod: `greet` echoes both back, which is how the e2e proves
  they arrived.
- `labels` stamps platform-owned tags on every generated Deployment/Service.
- `on_event` streams typed progress events (`provision -> bundle -> apply ->
  rollout` plus engine log lines) while the deploy runs.

The real-cluster e2e that exercises this example lives at
`jac/jaclang/scale/tests/deploy/sdk_deploy_real_e2e.sh` and runs in CI on the
kind cluster of the `k8s-real-e2e` job.
