import os;
import shutil;
import subprocess;
import from pathlib { Path }
import from jaclang.toolchains.host { run_step }
import from jaclang.toolchains.store { offline }

def install_linux_packages(packages: dict[str, list[str]]) {
    if offline() {
        raise RuntimeError(
            "Required system libraries are missing and JAC_OFFLINE is enabled. Run setup online first."
        );
    }
    for (manager, names) in packages.items() {
        binary = shutil.which(manager);
        if not binary {
            continue;
        }
        prefix: list[str] = [];
        if os.geteuid() != 0 {
            sudo = shutil.which("sudo");
            if not sudo {
                raise RuntimeError(
                    f"Administrator access is needed to install {', '.join(
                        names
                    )} using {manager}. Install these packages and retry."
                );
            }
            prefix = [sudo];
            if not os.isatty(0) {
                prefix.append("-n");
            }
        }
        if manager == "apt-get" {
            run_step(
                "Updating system package index (administrator access required)",
                prefix + [binary, "update"],
                Path.cwd(),
                dict(os.environ)
            );
        }
        options = ["-S", "--needed", "--noconfirm"]
            if manager == "pacman"
            else ["install", "-y"];
        run_step(
            "Installing native build dependencies: " + ", ".join(names),
            prefix + [binary] + options + names,
            Path.cwd(),
            dict(os.environ)
        );
        return;
    }
    raise RuntimeError(
        "No supported system package manager found. Install a C++ compiler, pkg-config, GTK3, WebKitGTK 4.1, and patchelf, then retry."
    );
}

def webkit_module -> str {
    pkg = shutil.which("pkg-config");
    if not pkg {
        return "";
    }
    for name in ["webkit2gtk-4.1", "webkit2gtk-4.0"] {
        if subprocess.run([pkg, "--exists", name], capture_output=True).returncode
            == 0 {
            return name;
        }
    }
    return "";
}

def ensure_linux_desktop {
    import from jaclang.toolchains.host { host_platform }
    host = host_platform();
    if not host.startswith("linux-") {
        raise RuntimeError(
            f"The current desktop native build backend supports Linux hosts, not {host}."
        );
    }
    if webkit_module() and shutil.which("g++") {
        return;
    }
    install_linux_packages(
        {
            "apt-get": ["g++", "pkg-config", "libgtk-3-dev", "libwebkit2gtk-4.1-dev"],
            "dnf": [
                "gcc-c++",
                "pkgconf-pkg-config",
                "gtk3-devel",
                "webkit2gtk4.1-devel"
            ],
            "pacman": ["gcc", "pkgconf", "gtk3", "webkit2gtk-4.1"]
        }
    );
    if not webkit_module() or not shutil.which("g++") or not shutil.which("patchelf") {
        raise RuntimeError(
            "Desktop dependencies remain unavailable after package installation."
        );
    }
}


def ensure_patchelf -> str {
    found = shutil.which("patchelf");
    if found {
        return found;
    }
    import from jaclang.toolchains.pins { PATCHELF_ARTIFACTS }
    import from jaclang.toolchains.store { install }
    import from jaclang.toolchains.host { host_platform }
    artifact = PATCHELF_ARTIFACTS.get(host_platform());
    if artifact is None {
        raise RuntimeError("No patchelf distribution for this host.");
    }
    marker = "patchelf-0.17.2.4.data/scripts/patchelf";
    directory = install(artifact, marker);
    return str(directory / marker);
}
