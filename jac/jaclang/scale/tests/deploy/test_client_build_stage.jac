"""The host client build runs on the same staged, filtered copy that defines
the .jab's membership (issue #8104): what .jacignore parks and what the deploy
strips (.env, raw jac.toml, key material) is invisible to the build, so host
build inputs equal pod inputs by construction. A build that references a file
outside membership fails loud on the host, naming the file and the exclusion.

These drive the real ManifestBuilder; the recording builds use the codebase's
own JAC_EXECUTABLE substitution seam, not a mock."""

import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder { ManifestBuilder }
import from jaclang.scale.injector.bundle { bundle_source_files }

glob _PARKED: str = "# parked for the deploy\ndocsite/\nevaluation/\n";


def _builder(project_dir: str) -> ManifestBuilder {
    mb = ManifestBuilder(
        k8s_config=KubernetesConfig(app_name="shop", namespace="jb-shop"),
        microservices_config={"client": {"entry": "main.jac"}}
    );
    mb.project_dir = project_dir;
    return mb;
}


"""The issue-8044 tree shape, with the pieces the raw-tree build used to see:
a .env, a [scale.secrets] table, and two trees .jacignore parks."""
def _app(jacignore: (str | None) = None) -> str {
    d = tempfile.mkdtemp(prefix="client-stage-");
    files = {
        "jac.toml": (
            '[project]\nname = "shop"\nentry-point = "main.jac"\n\n'
            '[scale.secrets]\nAPI_KEY = "sk-live-8104"\n'
        ),
        "main.jac": (
            "def:pub app() -> JsxElement {\n"
            "    return <div>shop</div>;\n"
            "}\n\n"
            "with entry {}\n"
        ),
        "svc.jac": "def:pub ping -> str { return \"pong\"; }\n",
        ".env": "VITE_API_KEY=sk-live-8104\n"
    };
    for (name, source) in files.items() {
        with open(os.path.join(d, name), "w", encoding="utf-8") as f {
            f.write(source);
        }
    }
    os.mkdir(os.path.join(d, "docsite"));
    with open(os.path.join(d, "docsite", "util.jac"), "w", encoding="utf-8") as f {
        f.write("def helper -> str { return \"x\"; }\n");
    }
    os.mkdir(os.path.join(d, "evaluation"));
    with open(
        os.path.join(d, "evaluation", "broken.jac"), "w", encoding="utf-8"
    ) as f {
        f.write("this is not valid jac\n");
    }
    if jacignore is not None {
        with open(os.path.join(d, ".jacignore"), "w", encoding="utf-8") as f {
            f.write(jacignore);
        }
    }
    return d;
}


"""A jac stand-in that records the build's working tree instead of building:
on `build` it writes the cwd, the sorted file listing, and the jac.toml it
sees into `record_dir`, then fabricates a dist. Every other subcommand (the
dependency install) exits clean without touching the network."""
def _recording_jac(tmp: str, record_dir: str, build_exit: int = 0) -> str {
    script = os.path.join(tmp, "recording-jac.sh");
    with open(script, "w", encoding="utf-8") as f {
        f.write(
            "#!/bin/sh\n"
                + 'if [ "$1" != "build" ]; then exit 0; fi\n'
                + f'pwd > "{record_dir}/cwd"\n'
                + "find . -type f | sed 's|^\\./||' | sort > "
                + f'"{record_dir}/files"\n'
                + f'cp jac.toml "{record_dir}/jac.toml" 2>/dev/null || true\n'
                + f'if [ "{build_exit}" != "0" ]; then\n'
                + '  echo "cannot import docsite/util.jac: no such module" >&2\n'
                + f"  exit {build_exit}\n"
                + "fi\n"
                + "mkdir -p .jac/client/dist\n"
                + 'echo "<html></html>" > .jac/client/dist/index.html\n'
                + "exit 0\n"
        );
    }
    os.chmod(script, 0o755);
    return script;
}


def _with_recording_build(
    project_dir: str, build_exit: int = 0
) -> tuple[(Exception | None), str] {
    tmp = tempfile.mkdtemp(prefix="client-stage-rec-");
    script = _recording_jac(tmp, tmp, build_exit);
    saved = os.environ.get("JAC_EXECUTABLE");
    os.environ["JAC_EXECUTABLE"] = script;
    raised = None;
    try {
        _builder(project_dir)._build_client_bundle(project_dir);
    } except Exception as e {
        raised = e;
    } finally {
        if saved is None {
            os.environ.pop("JAC_EXECUTABLE", None);
        } else {
            os.environ["JAC_EXECUTABLE"] = saved;
        }
    }
    return (raised, tmp);
}


test "the client build's inputs are the bundle's membership, nothing more" {
    project_dir = _app(_PARKED);
    base = Path(project_dir);
    expected: set[str] = {
        p.relative_to(base).as_posix() for p in bundle_source_files(base)
    };
    expected |= {"jac.toml", "__init__.jac"};
    (raised, rec) = _with_recording_build(project_dir);
    try {
        assert raised is None , f"the staged build must succeed: {raised}";
        with open(os.path.join(rec, "files"), encoding="utf-8") as f {
            staged = set(f.read().splitlines());
        }
        assert staged == expected , (
            f"the build saw a different tree than the bundle ships:\n"
            f"extra: {sorted(staged - expected)}\n"
            f"missing: {sorted(expected - staged)}"
        );
        assert ".env" not in staged , staged;
        assert not any([n.startswith("docsite/") for n in staged]) , staged;
        assert not any([n.startswith("evaluation/") for n in staged]) , staged;
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
        shutil.rmtree(rec, ignore_errors=True);
    }
}


test "the build reads the sanitized jac.toml, not the raw one" {
    project_dir = _app(_PARKED);
    (raised, rec) = _with_recording_build(project_dir);
    try {
        assert raised is None , f"the staged build must succeed: {raised}";
        with open(os.path.join(rec, "jac.toml"), encoding="utf-8") as f {
            staged_toml = f.read();
        }
        assert "[project]" in staged_toml , staged_toml;
        assert "scale.secrets" not in staged_toml , staged_toml;
        assert "sk-live-8104" not in staged_toml , staged_toml;
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
        shutil.rmtree(rec, ignore_errors=True);
    }
}


test "the build runs in an ephemeral stage and the dist is copied back" {
    project_dir = _app(_PARKED);
    (raised, rec) = _with_recording_build(project_dir);
    try {
        assert raised is None , f"the staged build must succeed: {raised}";
        with open(os.path.join(rec, "cwd"), encoding="utf-8") as f {
            build_cwd = f.read().strip();
        }
        assert Path(build_cwd).resolve() != Path(project_dir).resolve() , (
            "the build still ran on the raw project tree"
        );
        assert not os.path.isdir(build_cwd) , (
            "the deploy left its staging directory behind"
        );
        index_html = os.path.join(
            project_dir, ".jac", "client", "dist", "index.html"
        );
        assert os.path.isfile(index_html) , (
            "the built dist never made it back to where the bundle pack "
            "ships it from"
        );
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
        shutil.rmtree(rec, ignore_errors=True);
    }
}


test "a client entry parked by .jacignore fails the deploy, naming the pattern" {
    project_dir = _app(_PARKED + "main.jac\n");
    raised = None;
    try {
        _builder(project_dir)._build_client_bundle(project_dir);
    } except ValueError as e {
        raised = e;
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }

    assert raised is not None , (
        "a parked client entry must fail the deploy loud, not silently skip "
        "the build"
    );
    message = str(raised);
    assert "main.jac" in message , message;
    assert ".jacignore" in message , message;
    assert "'main.jac'" in message , (
        f"the error must name the matching pattern: {message}"
    );
}


test "a build that references a parked file names it and the pattern" {
    project_dir = _app(_PARKED);
    (raised, rec) = _with_recording_build(project_dir, build_exit=1);
    try {
        assert raised is not None , "a broken client build must fail the deploy";
        message = str(raised);
        assert "client build failed" in message , message;
        assert "docsite/util.jac" in message , message;
        assert "'docsite'" in message , (
            f"the error must name the matching .jacignore pattern: {message}"
        );
        assert "never ship" in message , message;
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
        shutil.rmtree(rec, ignore_errors=True);
    }
}


test "the same reference fails silently nowhere: unparked, it just builds" {
    project_dir = _app(None);
    (raised, rec) = _with_recording_build(project_dir);
    try {
        assert raised is None , f"an unparked tree must build: {raised}";
        with open(os.path.join(rec, "files"), encoding="utf-8") as f {
            staged = set(f.read().splitlines());
        }
        assert "docsite/util.jac" in staged , staged;
        assert ".env" not in staged , (
            ".env never ships, .jacignore or not"
        );
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
        shutil.rmtree(rec, ignore_errors=True);
    }
}
