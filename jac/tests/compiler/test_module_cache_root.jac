"""A module's cache lives under its own project, whatever the ambient config says.

The cache root used to come from the process-wide project config. That value
is empty during parts of a build, and the helper then fell back to a
`.jac/cache` directory beside the module, so the same module's cache entries
landed in different places across a run: written once under the project,
looked for later beside the file, and recompiled. The root now follows the
`jac.toml` nearest to the module's own path.
"""

import os;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.jir { get_module_cache_path }
import from jaclang.project.config { get_config, project_scope_is_pinned, set_config }


test "a module's cache path follows the jac.toml above it, not the ambient config" {
    base = Path(os.path.realpath(tempfile.mkdtemp(prefix="jac_cache_root_")));
    (base / "jac.toml").write_text('[project]\nname = "rooted"\n');
    sub = base / "shared";
    sub.mkdir();
    mod = sub / "util.jac";
    mod.write_text("def two -> int {\n    return 2;\n}\n");
    pinned = project_scope_is_pinned();
    saved = get_config();
    try {
        set_config(None);
        without_ambient = get_module_cache_path(str(mod));
    } finally {
        if pinned {
            set_config(saved);
        } else {
            set_config(None);
            get_config(force_discover=True);
        }
    }
    with_ambient = get_module_cache_path(str(mod));
    project_cache = (base / ".jac" / "cache").resolve();
    assert without_ambient.resolve().is_relative_to(project_cache) , (
        f"with no ambient config the cache must still sit under the module's "
        f"project, got {without_ambient}"
    );
    assert without_ambient == with_ambient , (
        "the cache path must not depend on the ambient config: "
        f"{without_ambient} vs {with_ambient}"
    );
}
