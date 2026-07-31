"""Programmatic deploy driver for the sdk-greeter example.

The SDK equivalent of `jac start main.jac --scale`: the whole deploy
configuration lives on a DeploySpec, jac.toml is never read on the deploy
side, and the run streams typed progress events.

    jac run deploy.jac deploy     # deploy the app in this folder
    jac run deploy.jac status     # full status dict
    jac run deploy.jac url        # externally reachable URL (or empty)
    jac run deploy.jac destroy    # tear the deployment down; never prompts

Env overrides (used by the e2e harness): SDK_DEPLOY_NAMESPACE,
SDK_DEPLOY_APP_NAME, SDK_DEPLOY_STORAGE_CLASS, SDK_DEPLOY_GREETING,
SDK_DEPLOY_SECRET, E2E_POD_BASE_IMAGE.
"""
import json;
import os;
import sys;
import from jaclang.scale.sdk { DeploySpec, ProgressEvent, ScaleClient }

glob APP_NAME: str = os.environ.get("SDK_DEPLOY_APP_NAME", "sdk-greeter"),
     NAMESPACE: str = os.environ.get("SDK_DEPLOY_NAMESPACE", "sdk-greeter"),
     STORAGE_CLASS: str = os.environ.get("SDK_DEPLOY_STORAGE_CLASS", ""),
     GREETING: str = os.environ.get("SDK_DEPLOY_GREETING", "hello"),
     SECRET: str = os.environ.get("SDK_DEPLOY_SECRET", "s3cret-demo"),
     POD_BASE_IMAGE: str = os.environ.get("E2E_POD_BASE_IMAGE", "");


def build_spec -> DeploySpec {
    return DeploySpec(
        app_name=APP_NAME,
        namespace=NAMESPACE,
        source=os.path.dirname(os.path.abspath(__file__)) or ".",
        env={"GREETING_PREFIX": GREETING},
        secrets={"GREETER_SECRET": SECRET},
        labels={"jac-scale.example": "sdk-deploy"},
        client={"entry": False},
        microservices={"routes": {"greeter": "/greeter"}},
        extra={"bundle_storage_class": STORAGE_CLASS, "python_image": POD_BASE_IMAGE}
    );
}


def print_event(event: ProgressEvent) {
    print(f"[{event.phase}:{event.status}] {event.message}", flush=True);
}


with entry {
    action = sys.argv[1] if len(sys.argv) > 1 else "";
    if action not in ("deploy", "preview", "status", "url", "destroy") {
        print("usage: jac run deploy.jac [deploy|preview|status|url|destroy]");
        sys.exit(2);
    }
    client = ScaleClient();
    if action == "preview" {
        bundle = client.preview(build_spec());
        gateway_args = bundle["deployments"]["__gateway__"]["spec"]["template"]["spec"][
            "containers"
        ][0]["args"];
        print(
            json.dumps(
                {
                    "deployments": sorted(bundle["deployments"].keys()),
                    "gateway_args": gateway_args
                }
            )
        );
    } elif action == "deploy" {
        result = client.deploy(build_spec(), on_event=print_event);
        if not result.success {
            print(f"DEPLOY_FAILED: {result.message}");
            sys.exit(1);
        }
        print(f"DEPLOY_OK service_url={result.service_url or ''}");
    } elif action == "status" {
        print(
            json.dumps(
                client.status(APP_NAME, NAMESPACE, target="kubernetes-microservice")
            )
        );
    } elif action == "url" {
        print(
            client.service_url(APP_NAME, NAMESPACE, target="kubernetes-microservice")
                or ""
        );
    } else {
        client.destroy(APP_NAME, NAMESPACE, target="kubernetes-microservice");
        print("DESTROY_OK");
    }
}
