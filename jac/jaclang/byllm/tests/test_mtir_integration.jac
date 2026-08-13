"""Tests for MTIR (Meaning Typed IR) integration with byLLM.

These tests verify byLLM-specific MTIR functionality:
1. Schema generation data structures work correctly
2. Tool schema generation with MTIR info
3. MTIR caching works correctly
4. Python library fallback mode works when MTIR is unavailable

Note: MTIR extraction from compiled code is tested in:
  jac/tests/compiler/passes/main/test_mtir_gen_pass.py
"""

import io;
import os;
import sys;
import tempfile;
import from dataclasses { fields }
import from pathlib { Path }

import from jaclang { JacRuntime }
import from jaclang { JacRuntimeInterface as Jac }
import from jaclang.jac0core.mtp {
    ClassInfo,
    EnumInfo,
    FieldInfo,
    FunctionInfo,
    MethodInfo,
    ParamInfo,
    mk_dict,
    mk_list,
}
import from jaclang.jac0core.program { JacProgram }

glob jac_import = Jac.jac_import,
     FIXTURE_DIR = os.path.join(os.path.dirname(__file__), "fixtures");

"""Get absolute path of a fixture from fixtures directory."""
def fixture_path(fixture: str) -> str {
    file_path = os.path.join(FIXTURE_DIR, fixture);
    return os.path.abspath(file_path);
}

"""Flatten every per-module MTIR slice into one {scope: info} view for tests.

Production never builds this: fetch_mtir resolves a single module's slice
directly from mtir_by_module. This helper only stands in for the removed flat
mtir_map in tests that scan scopes program-wide.
"""
def all_mtir -> dict {
    prog = JacRuntime.program;
    if prog is None {
        return {};
    }
    out: dict = {};
    for slice in prog.mtir_by_module.values() {
        out.update(slice);
    }
    return out;
}

# =============================================================================
# Schema Generation Data Structure Tests
# =============================================================================
test "field semstrings in schema" {
    field_info = FieldInfo(
        name="username", semstr="Unique username for login.", type_info="str",
    );
    class_info = ClassInfo(
        name="User",
        semstr="A registered user in the system.",
        fields=[field_info],
        base_classes=[],
        methods=[],
    );

    assert class_info.name == "User";
    assert class_info.semstr == "A registered user in the system.";
    assert len(class_info.fields) == 1;
    assert class_info.fields[0].name == "username";
    assert class_info.fields[0].semstr == "Unique username for login.";
}

test "param info structure" {
    param_info = ParamInfo(
        name="criteria",
        semstr="Description of the type of person to generate.",
        type_info="str",
    );

    assert param_info.name == "criteria";
    assert param_info.semstr == "Description of the type of person to generate.";
    assert param_info.type_info == "str";
}

test "function info for tool schema" {
    params = [
        ParamInfo(name="birth_year", semstr="Year of birth.", type_info="int"),
        ParamInfo(
            name="current_year",
            semstr="Current year for calculation.",
            type_info="int",
        ),

    ];
    func_info = FunctionInfo(
        name="calculate_age",
        semstr="Calculate age from birth year.",
        params=params,
        return_type="int",
    );

    assert func_info.name == "calculate_age";
    assert func_info.semstr == "Calculate age from birth year.";
    assert func_info.params is not None;
    assert len(func_info.params) == 2;
    assert func_info.params[0].name == "birth_year";
    assert func_info.params[0].semstr == "Year of birth.";
}

test "nested class info" {
    person_class = ClassInfo(
        name="Person",
        semstr="A person entity.",
        fields=[
            FieldInfo(name="name", semstr="Full name.", type_info="str"),
            FieldInfo(name="age", semstr="Age in years.", type_info="int"),

        ],
        base_classes=[],
        methods=[],
    );

    user_class = ClassInfo(
        name="User",
        semstr="A user with address.",
        fields=[
            FieldInfo(name="username", semstr="Login name.", type_info="str"),
            FieldInfo(name="friend", semstr="A friend.", type_info=person_class),

        ],
        base_classes=[],
        methods=[],
    );

    assert user_class.fields[1].type_info == person_class;
    assert isinstance(user_class.fields[1].type_info, ClassInfo);
    assert user_class.fields[1].type_info.name == "Person";
}

test "generic type encoding" {
    list_type = mk_list("Person");
    assert list_type == ("list", "Person");

    dict_type = mk_dict("str", "int");
    assert dict_type == ("dict", "str", "int");

    person_info = ClassInfo(
        name="Person", semstr="A person.", fields=[], base_classes=[], methods=[]
    );
    nested_list = mk_list(person_info);
    assert nested_list[0] == "list";
    assert nested_list[1].name == "Person";
}

# =============================================================================
# Tool Schema Tests
# =============================================================================
test "tool extraction from compiled code" {
    prog = JacProgram();
    prog.compile(fixture_path("tool_function.jac"));
    assert not prog.errors_had;

    assert JacRuntime.program is not None;
    mtir_map = all_mtir();

    func_with_tools = None;
    for (scope, info) in mtir_map.items() {
        if (
            isinstance(info, FunctionInfo)
            and info.tools
            and "tool_function" in scope
            and info.name == "get_person_details"
        ) {
            func_with_tools = info;
            break;
        }
    }

    assert func_with_tools is not None , "Should find get_person_details with tools";
    assert func_with_tools.tools is not None;
    assert len(func_with_tools.tools) == 2;

    tool_names = [t.name for t in func_with_tools.tools];
    assert "calculate_age" in tool_names;
    assert "format_name" in tool_names;

    for tool in func_with_tools.tools {
        assert isinstance(tool, FunctionInfo);
        assert tool.semstr is not None;
    }
}

test "method tool in class" {
    prog = JacProgram();
    prog.compile(fixture_path("tool_method.jac"));
    assert not prog.errors_had;

    assert JacRuntime.program is not None;
    mtir_map = all_mtir();

    method_scope = None;
    for scope in mtir_map {
        if "eval_expression" in scope and "tool_method" in scope {
            method_scope = scope;
            break;
        }
    }

    assert method_scope is not None , "Should find eval_expression method";
    method_info = mtir_map[method_scope];
    assert isinstance(method_info, MethodInfo);

    assert method_info.tools is not None;
    tool_names = [t.name for t in method_info.tools];
    assert "add" in tool_names , f"Expected 'add' in tools, got: {tool_names}";
    assert "multiply" in tool_names , f"Expected 'multiply' in tools, got: {tool_names}";
}

# =============================================================================
# Python Library Fallback Tests
# =============================================================================
test "mtruntime without mtir info" {
    import from jaclang.jac0core.mtp { MTIR }

    def sample_func(x: int, y: str) -> str {
        return f"{y}: {x}";
    }

    mtir = MTIR(
        caller=sample_func, args={0: 42, 1: "test"}, call_params={}, ir_info=None,
    );

    runtime = mtir.runtime;
    assert runtime is not None;
    assert runtime.caller == sample_func;
}

test "python lib mode fixture" {
    import from fixtures { python_lib_mode }
    assert hasattr(python_lib_mode, "Person");
    assert hasattr(python_lib_mode, "get_person_info");
    assert hasattr(python_lib_mode, "llm");

    person_fields = {f.name for f in fields(python_lib_mode.Person)};
    assert "name" in person_fields;
    assert "birth_year" in person_fields;
    assert "description" in person_fields;
}

# =============================================================================
# MTIR Caching Tests
# =============================================================================
test "jir cache path for source" {
    import from jaclang.jac0core.jir { get_module_cache_path }

    cache_path = get_module_cache_path("/path/to/test.jac");
    assert cache_path is not None;
    assert str(cache_path).endswith(".jir");
}

test "jir cache has sec mtir constant" {
    import from jaclang.jac0core.jir { SEC_MTIR, SEC_BYTECODE, SECTIONS_MAGIC }

    assert SEC_MTIR == 0x03;
    assert SEC_BYTECODE == 0x02;
    assert len(SECTIONS_MAGIC) == 4;
}

test "mtir roundtrip via jir cache" {
    import pickle;
    import shutil;
    import from jaclang.jac0core.jir {
        get_module_cache_path,
        write_sections,
        read_sections,
        SECTIONS_MAGIC,
        HEADER_SIZE,
        SEC_MTIR
    }
    import from jaclang.jac0core.jir_passes { JirWriter }
    import from jaclang.jac0core.unitree { Module }

    tmp_path = Path(tempfile.mkdtemp());
    test_file = tmp_path / "test.jac";
    test_file.write_text("glob x = 1;\n");

    test_mtir_map: dict = {
        "test.func1": FunctionInfo(
            name="func1",
            semstr="Test function one.",
            params=[ParamInfo(name="x", semstr="Input x.", type_info="int")],
            return_type="str",
        ),

    };

    # Write a minimal JIR with SEC_MTIR section
    mtir_bytes = pickle.dumps(test_mtir_map);
    secs: dict[int, bytes] = {SEC_MTIR: mtir_bytes};
    section_blob = write_sections(secs);

    # Read back the sections from the blob (skip the SECTIONS_MAGIC header)
    magic: object = SECTIONS_MAGIC;
    start = len(magic);
    recovered = read_sections(section_blob, start);

    assert SEC_MTIR in recovered , "SEC_MTIR should be present";
    retrieved = pickle.loads(recovered[SEC_MTIR]);
    assert "test.func1" in retrieved;
    assert retrieved["test.func1"].name == "func1";
    assert retrieved["test.func1"].semstr == "Test function one.";

    shutil.rmtree(str(tmp_path), ignore_errors=True);
}

test "jir cache stores per module mtir only" {
    import pickle;
    import shutil;
    import from jaclang.jac0core.compiler { JacCompiler }
    import from jaclang.jac0core.jir {
        get_module_cache_path,
        find_sections,
        SEC_MTIR,
        mtir_module_stem,
        mtir_for_module
    }

    tmp_path = Path(tempfile.mkdtemp());
    heavy_file = tmp_path / "heavy.jac";
    plain_file = tmp_path / "plain.jac";
    shutil.copy(fixture_path("basic_compile.jac"), str(heavy_file));
    plain_file.write_text("glob x = 1;\n");

    assert JacRuntime.program is not None;
    prog = JacRuntime.program;
    compiler = JacCompiler();
    heavy_path = str(heavy_file);
    plain_path = str(plain_file);

    try {
        assert compiler.get_bytecode(heavy_path, prog) is not None;
        assert compiler.get_bytecode(plain_path, prog) is not None;

        heavy_cache = get_module_cache_path(heavy_path);
        plain_cache = get_module_cache_path(plain_path);
        assert heavy_cache.exists() , "heavy.jac JIR cache should exist";
        assert plain_cache.exists() , "plain.jac JIR cache should exist";

        plain_secs = find_sections(plain_cache.read_bytes());
        assert SEC_MTIR not in plain_secs , (
            "plain.jac should not cache program-wide MTIR when it has no by llm"
        );

        heavy_secs = find_sections(heavy_cache.read_bytes());
        assert SEC_MTIR in heavy_secs , "heavy.jac should cache its own MTIR";
        heavy_mtir = pickle.loads(heavy_secs[SEC_MTIR]);

        heavy_stem = mtir_module_stem(heavy_path);
        dot = heavy_stem + ".";
        for key in heavy_mtir {
            assert key == heavy_stem or key.startswith(dot) , (
                f"Unexpected MTIR key '{key}' in heavy.jac cache"
            );
        }

        expected_count = len(mtir_for_module(prog.mtir_by_module, heavy_path));
        assert len(heavy_mtir) == expected_count , (
            f"heavy.jac cache should store only its module MTIR "
            f"({expected_count} keys), got {len(heavy_mtir)}"
        );
        assert len(heavy_mtir) > 0 , "heavy.jac should have MTIR entries";
    } finally {
        for src in [heavy_path, plain_path] {
            cache_path = get_module_cache_path(src);
            if cache_path.exists() {
                cache_path.unlink();
            }
        }
        shutil.rmtree(str(tmp_path), ignore_errors=True);
    }
}

test "same-stem modules in different dirs keep mtir isolated" {
    # Regression guard for the collision class where pkg_a/utils.jac and
    # pkg_b/utils.jac share the stem "utils". The per-module mtir_by_module key
    # (dirname + stem) must keep their slices distinct so one module's cache
    # never carries the other's MTIR.
    import pickle;
    import shutil;
    import from jaclang.jac0core.compiler { JacCompiler }
    import from jaclang.jac0core.jir {
        get_module_cache_path,
        find_sections,
        mtir_module_key,
        mtir_for_module,
        SEC_MTIR
    }

    tmp_path = Path(tempfile.mkdtemp());
    dir_a = tmp_path / "pkg_a";
    dir_b = tmp_path / "pkg_b";
    dir_a.mkdir();
    dir_b.mkdir();
    file_a = dir_a / "utils.jac";
    file_b = dir_b / "utils.jac";
    # Same stem, distinct by-llm function names so cross-contamination is
    # detectable.
    src = fixture_path("basic_compile.jac");
    text_a = Path(src).read_text().replace("generate_person", "gen_a");
    text_b = Path(src).read_text().replace("generate_person", "gen_b");
    file_a.write_text(text_a);
    file_b.write_text(text_b);

    assert JacRuntime.program is not None;
    prog = JacRuntime.program;
    compiler = JacCompiler();
    path_a = str(file_a);
    path_b = str(file_b);

    try {
        assert compiler.get_bytecode(path_a, prog) is not None;
        assert compiler.get_bytecode(path_b, prog) is not None;

        # Distinct collision-free keys despite the shared stem.
        assert mtir_module_key(path_a) != mtir_module_key(path_b);

        slice_a = mtir_for_module(prog.mtir_by_module, path_a);
        slice_b = mtir_for_module(prog.mtir_by_module, path_b);
        a_keys = list(slice_a.keys());
        b_keys = list(slice_b.keys());
        assert any("gen_a" in k for k in a_keys) , "pkg_a slice missing gen_a";
        assert any("gen_b" in k for k in b_keys) , "pkg_b slice missing gen_b";
        assert not any("gen_b" in k for k in a_keys) , (
            "pkg_a slice leaked pkg_b MTIR"
        );
        assert not any("gen_a" in k for k in b_keys) , (
            "pkg_b slice leaked pkg_a MTIR"
        );

        # Each module's JIR cache carries only its own slice.
        cache_a = pickle.loads(
            find_sections(get_module_cache_path(path_a).read_bytes())[SEC_MTIR]
        );
        cache_b = pickle.loads(
            find_sections(get_module_cache_path(path_b).read_bytes())[SEC_MTIR]
        );
        assert any("gen_a" in k for k in cache_a);
        assert not any("gen_b" in k for k in cache_a) , (
            "pkg_a JIR cache leaked pkg_b MTIR"
        );
        assert any("gen_b" in k for k in cache_b);
        assert not any("gen_a" in k for k in cache_b) , (
            "pkg_b JIR cache leaked pkg_a MTIR"
        );
    } finally {
        for src_path in [path_a, path_b] {
            cache_path = get_module_cache_path(src_path);
            if cache_path.exists() {
                cache_path.unlink();
            }
        }
        shutil.rmtree(str(tmp_path), ignore_errors=True);
    }
}

test "invalidate module clears stale mtir" {
    import shutil;
    import from jaclang.jac0core.compiler { JacCompiler }
    import from jaclang.jac0core.jir {
        get_module_cache_path,
        mtir_for_module,
        mtir_module_key,
    }

    tmp_path = Path(tempfile.mkdtemp());
    jac_file = tmp_path / "stale_mtir.jac";
    shutil.copy(fixture_path("basic_compile.jac"), str(jac_file));
    path = str(jac_file.resolve());
    plain_content = "glob x = 1;\n";

    assert JacRuntime.program is not None;
    prog = JacRuntime.program;
    compiler = JacCompiler();

    try {
        assert compiler.get_bytecode(path, prog) is not None;
        module_mtir = mtir_for_module(prog.mtir_by_module, path);
        assert len(module_mtir) > 0 , "by llm compile should populate module MTIR";

        mod_key = mtir_module_key(path);
        prog.invalidate_module(path);

        # Single source of truth: the slice is gone, so the scope is gone.
        # (No second map to keep in sync — cleanup key == storage key.)
        assert mod_key not in prog.mtir_by_module , (
            "mtir_by_module slice should be removed on invalidation"
        );

        jac_file.write_text(plain_content);
        assert compiler.get_bytecode(path, prog) is not None;

        module_mtir_after = mtir_for_module(prog.mtir_by_module, path);
        assert len(module_mtir_after) == 0 , (
            "Recompile without by llm should not restore stale MTIR"
        );
    } finally {
        cache_path = get_module_cache_path(path);
        if cache_path.exists() {
            cache_path.unlink();
        }
        shutil.rmtree(str(tmp_path), ignore_errors=True);
    }
}

test "filter_module_mtir keeps only the target module's scopes" {
    import from jaclang.jac0core.jir { filter_module_mtir }

    # Pre-deduplication JIR caches stored the whole program-wide MTIR map in
    # every module's SEC_MTIR (FORMAT_VERSION stayed at 18, so those legacy
    # blobs still pass the validity checks). The restore path must trim such a
    # blob down to the scopes rooted at the target module's stem.
    marker = FunctionInfo(name="f", semstr="s");
    legacy: dict = {
        "own.gen_a": marker,
        "own.Inner.helper": marker,
        "other.gen_b": marker,
        "third.thing": marker,

    };
    kept = filter_module_mtir("/tmp/dir/own.jac", legacy);
    assert "own.gen_a" in kept , "keep module-level scope";
    assert "own.Inner.helper" in kept , "keep nested scope under stem";
    assert "other.gen_b" not in kept , "drop foreign module scope";
    assert "third.thing" not in kept , "drop other foreign scope";
    assert len(kept) == 2 , f"expected 2 kept scopes, got {len(kept)}";
}

test "filter_module_mtir disambiguates same-stem dirs via bytecode" {
    import shutil;
    import from jaclang.jac0core.compiler { JacCompiler }
    import from jaclang.jac0core.jir {
        filter_module_mtir,
        find_sections,
        get_module_cache_path,
        SEC_BYTECODE,
    }

    # Same stem in different directories: stem-only filtering cannot tell
    # utils.gen_a from utils.gen_b, but bytecode symtab validation can.
    tmp_path = Path(tempfile.mkdtemp());
    dir_a = tmp_path / "pkg_a";
    dir_b = tmp_path / "pkg_b";
    dir_a.mkdir();
    dir_b.mkdir();
    file_a = dir_a / "utils.jac";
    file_b = dir_b / "utils.jac";
    src = fixture_path("basic_compile.jac");
    file_a.write_text(Path(src).read_text().replace("generate_person", "gen_a"));
    file_b.write_text(Path(src).read_text().replace("generate_person", "gen_b"));

    assert JacRuntime.program is not None;
    prog = JacRuntime.program;
    compiler = JacCompiler();
    path_a = str(file_a);

    marker = FunctionInfo(name="f", semstr="s");
    collision: dict = {"utils.gen_a": marker, "utils.gen_b": marker,};
    try {
        assert compiler.get_bytecode(path_a, prog) is not None;
        bc = find_sections(get_module_cache_path(path_a).read_bytes())[SEC_BYTECODE];
        kept = filter_module_mtir(path_a, collision, bc);
        assert "utils.gen_a" in kept , "keep scope defined in this module";
        assert "utils.gen_b" not in kept , (
            "drop same-stem foreign scope not in bytecode symtab"
        );
        assert len(kept) == 1 , f"expected 1 kept scope, got {len(kept)}";
    } finally {
        cache_path = get_module_cache_path(path_a);
        if cache_path.exists() {
            cache_path.unlink();
        }
        shutil.rmtree(str(tmp_path), ignore_errors=True);
    }
}

test "filter_module_mtir rejects foreign same-stem identical-qualname survivors" {
    # Two modules share the stem "utils" but live in different directories and
    # each exposes a function with the identical qualified scope "utils.gen".
    # A legacy program-wide blob collapses them to one surviving entry, and the
    # stem+bytecode filter cannot tell it belongs to the other module, so the
    # survivor would be stored as this module's slice. The per-entry mod_path
    # stamp (set at generation) lets the restore path reject it even though
    # stem and qualified scope both match.
    import from jaclang.jac0core.jir { filter_module_mtir }

    target = os.path.realpath("/tmp/pkg_a/utils.jac");
    foreign_path = os.path.realpath("/tmp/pkg_b/utils.jac");
    foreign = FunctionInfo(name="gen", semstr="b", mod_path=foreign_path);
    legacy: dict = {"utils.gen": foreign};

    kept = filter_module_mtir(target, legacy);
    assert "utils.gen" not in kept , "foreign survivor must be rejected";
    assert len(kept) == 0 , "expected empty slice";

    own_entry = FunctionInfo(name="gen", semstr="a", mod_path=target);
    legacy_own: dict = {"utils.gen": own_entry};
    kept_own = filter_module_mtir(target, legacy_own);
    assert "utils.gen" in kept_own , "own entry must survive";

    # A same-dir .impl annex shares the module key (the stem rekey collapses
    # .impl onto the base), so its entry belongs to the same logical module.
    impl_path = os.path.realpath("/tmp/pkg_a/utils.impl.jac");
    impl_entry = FunctionInfo(name="gen_impl", semstr="impl", mod_path=impl_path);
    legacy_impl: dict = {"utils.gen_impl": impl_entry};
    kept_impl = filter_module_mtir(target, legacy_impl);
    assert "utils.gen_impl" in kept_impl , "same-dir impl annex must be kept";
}

test "invalidate internal clears mirrored runtime mtir for owning compiler" {
    import from jaclang.jac0core.compiler { JacCompiler }
    import from jaclang.jac0core.jir { mtir_module_key }

    # The JIR restore path runs inside get_bytecode, which records the owning
    # compiler on the runtime program (rt._compiler = compiler) before it
    # mirrors a module's MTIR slice there. So a standalone JacCompiler that
    # mirrored into the runtime is the same compiler family, and invalidating
    # its internal program must clear the mirrored runtime slice. This is the
    # flip side of the cross-family isolation test: pairing is anchored on the
    # compiler identity that get_bytecode records, not on the runtime singleton.
    assert JacRuntime.program is not None;
    prog = JacRuntime.program;
    saved_compiler = prog._compiler;
    compiler = JacCompiler();
    internal = compiler.internal_program;
    assert internal._compiler is compiler;
    prog._compiler = compiler;

    path = os.path.realpath("/tmp/coord_probe/mirrored.jac");
    mod_key = mtir_module_key(path);
    marker = FunctionInfo(name="f", semstr="s");
    try {
        prog.mtir_by_module[mod_key] = {"mirrored.run": marker};
        internal.mtir_by_module[mod_key] = {"mirrored.run": marker};
        assert prog._compiler is compiler , (
            "runtime program records the mirroring compiler"
        );

        internal.invalidate_module(path);
        assert mod_key not in internal.mtir_by_module , "internal slice cleared";
        assert mod_key not in prog.mtir_by_module , (
            "mirrored runtime slice cleared within the owning compiler family"
        );
    } finally {
        prog._compiler = saved_compiler;
        if mod_key in prog.mtir_by_module {
            del (prog.mtir_by_module[mod_key], );
        }
        if mod_key in internal.mtir_by_module {
            del (internal.mtir_by_module[mod_key], );
        }
    }
}

test "invalidate_module clears mirrored mtir across program pair" {
    import from jaclang.jac0core.jir { mtir_module_key }

    # The restore path mirrors a module's MTIR slice into both the runtime and
    # internal programs; invalidating one must not leave a stale copy in the
    # other.
    assert JacRuntime.program is not None;
    prog = JacRuntime.program;
    compiler = prog._get_compiler();
    internal = compiler.internal_program;
    assert internal is not prog , "internal program is a distinct object";

    path = os.path.realpath("/tmp/coord_probe/paired.jac");
    mod_key = mtir_module_key(path);
    marker = FunctionInfo(name="f", semstr="s");
    try {
        prog.mtir_by_module[mod_key] = {"paired.run": marker};
        internal.mtir_by_module[mod_key] = {"paired.run": marker};
        assert mod_key in prog.mtir_by_module , "seeded runtime copy";
        assert mod_key in internal.mtir_by_module , "seeded internal copy";

        prog.invalidate_module(path);
        assert mod_key not in prog.mtir_by_module , "runtime slice cleared";
        assert mod_key not in internal.mtir_by_module , (
            "mirrored internal slice must not survive invalidation"
        );

        # Reverse direction: invalidating the internal program must also clear
        # the mirrored runtime copy.
        prog.mtir_by_module[mod_key] = {"paired.run": marker};
        internal.mtir_by_module[mod_key] = {"paired.run": marker};
        internal.invalidate_module(path);
        assert mod_key not in internal.mtir_by_module , ("internal slice cleared");
        assert mod_key not in prog.mtir_by_module , (
            "mirrored runtime slice must not survive invalidation"
        );
    } finally {
        if mod_key in prog.mtir_by_module {
            del (prog.mtir_by_module[mod_key], );
        }
        if mod_key in internal.mtir_by_module {
            del (internal.mtir_by_module[mod_key], );
        }
    }
}

test "invalidate_module spares unrelated runtime mtir" {
    import from jaclang.jac0core.jir { mtir_module_key }

    # An independent analysis program (CodeIntelligence's prog: a fresh
    # JacProgram that owns its own compiler) must not erase the live runtime
    # program's same-path MTIR slice when it invalidates a module. The two do
    # not share compiler or cache ownership, so a CodeIntelligence refresh must
    # leave runtime fetch_mtir lookups intact.
    assert JacRuntime.program is not None;
    rt = JacRuntime.program;
    rt_compiler = rt._get_compiler();

    ci_prog = JacProgram();
    ci_compiler = ci_prog._get_compiler();
    assert ci_compiler is not rt_compiler , (
        "analysis compiler must be distinct from the runtime compiler"
    );

    path = os.path.realpath("/tmp/coord_probe/independent.jac");
    mod_key = mtir_module_key(path);
    marker = FunctionInfo(name="g", semstr="s");
    try {
        rt.mtir_by_module[mod_key] = {"independent.g": marker};
        ci_prog.mtir_by_module[mod_key] = {"independent.g": marker};
        assert mod_key in rt.mtir_by_module , "seeded runtime slice";
        assert mod_key in ci_prog.mtir_by_module , "seeded analysis slice";

        ci_prog.invalidate_module(path);
        assert mod_key not in ci_prog.mtir_by_module , (
            "analysis slice cleared by its own invalidation"
        );
        assert mod_key in rt.mtir_by_module , (
            "runtime slice must survive an unrelated program's invalidation"
        );
    } finally {
        if mod_key in rt.mtir_by_module {
            del (rt.mtir_by_module[mod_key], );
        }
    }
}

# =============================================================================
# Fixture Compilation Test
# =============================================================================
test "basic fixture compiles" {
    prog = JacProgram();
    prog.compile(fixture_path("basic_compile.jac"));
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";

    assert JacRuntime.program is not None;
    mtir_map = all_mtir();
    assert len(mtir_map) > 0 , "MTIR map should have entries";

    found_generate_person = False;
    for scope in mtir_map {
        if "basic_compile" in scope and "generate_person" in scope {
            found_generate_person = True;
            break;
        }
    }

    assert found_generate_person , "Should have generate_person function in MTIR";
}

# =============================================================================
# Scope Name Consistency Tests
# =============================================================================
test "scope name with trailing a" {
    prog = JacProgram();
    fixture = fixture_path("test_schema.jac");
    prog.compile(fixture);
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";

    assert JacRuntime.program is not None;
    mtir_map = all_mtir();

    scopes_with_generate_data = [
        scope
        for scope in mtir_map
        if "generate_data" in scope
    ];

    assert len(scopes_with_generate_data) > 0 , f"Should find generate_data in MTIR map. Available scopes: {list(
        mtir_map.keys()
    )}";

    matching_scope = None;
    for scope in scopes_with_generate_data {
        if "test_schema.generate_data" in scope {
            matching_scope = scope;
            break;
        }
    }

    assert matching_scope is not None , f"Expected scope containing 'test_schema.generate_data', but found: {scopes_with_generate_data}. This indicates the module name may have been truncated.";

    assert isinstance(mtir_map[matching_scope], FunctionInfo);
}

test "scope name with trailing c" {
    prog = JacProgram();
    fixture = fixture_path("basic.jac");
    prog.compile(fixture);
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";

    assert JacRuntime.program is not None;
    mtir_map = all_mtir();

    scopes_with_get_basic = [
        scope
        for scope in mtir_map
        if "get_basic" in scope
    ];

    assert len(scopes_with_get_basic) > 0 , f"Should find get_basic in MTIR map. Available scopes: {list(
        mtir_map.keys()
    )}";

    matching_scope = None;
    for scope in scopes_with_get_basic {
        if "basic.get_basic" in scope {
            matching_scope = scope;
            break;
        }
    }

    assert matching_scope is not None , f"Expected scope containing 'basic.get_basic', but found: {scopes_with_get_basic}. Module name ending in 'c' may have been truncated.";
}

test "scope name with trailing j" {
    prog = JacProgram();
    fixture = fixture_path("proj.jac");
    prog.compile(fixture);
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";

    assert JacRuntime.program is not None;
    mtir_map = all_mtir();

    scopes_with_create_proj = [
        scope
        for scope in mtir_map
        if "create_proj" in scope
    ];

    assert len(scopes_with_create_proj) > 0 , f"Should find create_proj in MTIR map. Available scopes: {list(
        mtir_map.keys()
    )}";

    matching_scope = None;
    for scope in scopes_with_create_proj {
        if "proj.create_proj" in scope {
            matching_scope = scope;
            break;
        }
    }

    assert matching_scope is not None , f"Expected scope containing 'proj.create_proj', but found: {scopes_with_create_proj}. Module name ending in 'j' may have been truncated.";
}

test "all stored scopes are retrievable" {
    fixtures = ["test_schema.jac", "basic.jac", "proj.jac"];
    expected_functions = ["generate_data", "get_basic", "create_proj"];
    expected_modules = ["test_schema", "basic", "proj"];

    for (fixture_name, func_name, module_name) in zip(
        fixtures, expected_functions, expected_modules, strict=True
    ) {
        prog = JacProgram();
        prog.compile(fixture_path(fixture_name));
        assert not prog.errors_had , f"Compilation errors for {fixture_name}: {prog.errors_had}";

        assert JacRuntime.program is not None;
        mtir_map = all_mtir();

        expected_scope_pattern = f"{module_name}.{func_name}";

        matching_scopes = [
            scope
            for scope in mtir_map
            if expected_scope_pattern in scope
        ];

        assert len(matching_scopes) > 0 , f"Failed to find scope matching '{expected_scope_pattern}' in MTIR map for {fixture_name}. Available scopes: {list(
            mtir_map.keys()
        )}. This indicates module name '{module_name}' was not correctly preserved.";

        scope = matching_scopes[0];
        mtir_info = mtir_map[scope];
        assert mtir_info is not None;
        assert isinstance(mtir_info, FunctionInfo);
        assert mtir_info.name == func_name;
    }
}

test "scope name generation algorithm" {
    test_cases = [
        ("test_schema.jac", "generate_data", "test_schema.generate_data"),
        ("basic.jac", "get_basic", "basic.get_basic"),
        ("proj.jac", "create_proj", "proj.create_proj"),
        ("data.jac", "process_data", "data.process_data"),
        ("calc.jac", "calculate", "calc.calculate"),
        ("subj.jac", "analyze", "subj.analyze"),

    ];

    for (module_file, func_name, expected_scope) in test_cases {
        module_name = module_file.removesuffix(".jac");

        scope = f"{module_name}.{func_name}";

        assert scope == expected_scope , f"Scope name mismatch for {module_file}:{func_name}. Expected: {expected_scope}, Got: {scope}";

        assert not module_name.endswith(".") , f"Module name '{module_name}' appears to be corrupted (ends with period)";

        if module_file.endswith("a.jac") {
            assert module_name.endswith("a") , f"Module name '{module_name}' lost trailing 'a'";
        } elif module_file.endswith("c.jac") {
            assert module_name.endswith("c") , f"Module name '{module_name}' lost trailing 'c'";
        } elif module_file.endswith("j.jac") {
            assert module_name.endswith("j") , f"Module name '{module_name}' lost trailing 'j'";
        }
    }
}

test "imported function scope resolution" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;

    try {
        jac_import("importer_main", base_path=FIXTURE_DIR + "/");
    } finally {
        sys.stdout = sys.__stdout__;
    }

    stdout_value = captured_output.getvalue();

    assert "MTIR_TEST: Found scopes:" in stdout_value , f"MTIR test did not run or find scopes. Output:\n{stdout_value}";

    assert (
        "MTIR_TEST: Has correct scope with 'importable_schema': True" in stdout_value
    ) , (
        f"MTIR scope does not contain 'importable_schema'. "
        f"This indicates the module name 'importable_schema' (ending with 'a') "
        f"was truncated during compilation. Output:\n{stdout_value}"
    );

    assert "MTIR retrieval test: PASSED" in stdout_value , f"MTIR retrieval test failed. Output:\n{stdout_value}";
}

# =============================================================================
# Enum Extraction Tests
# =============================================================================
test "enum info structure" {
    members = [
        FieldInfo(name="RED", semstr="Red color.", type_info="int"),
        FieldInfo(name="GREEN", semstr="Green color.", type_info="int"),
        FieldInfo(name="BLUE", semstr="Blue color.", type_info="int"),

    ];
    enum_info = EnumInfo(
        name="Color", semstr="RGB color enumeration.", members=members,
    );

    assert enum_info.name == "Color";
    assert enum_info.semstr == "RGB color enumeration.";
    assert len(enum_info.members) == 3;
    assert enum_info.members[0].name == "RED";
    assert enum_info.members[0].type_info == "int";
    assert enum_info.members[0].semstr == "Red color.";
}

test "enum with int values extraction" {
    prog = JacProgram();
    prog.compile(fixture_path("enum_with_semstr.jac"));
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";

    assert JacRuntime.program is not None;
    mtir_map = all_mtir();

    func_scope = None;
    for scope in mtir_map {
        if "get_person_info" in scope and "enum_with_semstr" in scope {
            func_scope = scope;
            break;
        }
    }

    assert func_scope is not None , "Should find get_person_info function";
    func_info = mtir_map[func_scope];
    assert isinstance(func_info, FunctionInfo);

    assert isinstance(func_info.return_type, ClassInfo);
    person_class = func_info.return_type;

    personality_field = None;
    for field in person_class.fields {
        if field.name == "personality" {
            personality_field = field;
            break;
        }
    }

    assert personality_field is not None , "Person should have personality field";

    assert isinstance(personality_field.type_info, EnumInfo) , f"Expected EnumInfo, got {type(
        personality_field.type_info
    )}";

    personality_enum = personality_field.type_info;
    assert personality_enum.name == "Personality";
    assert len(personality_enum.members) == 3;

    member_names = [m.name for m in personality_enum.members];
    assert "INTROVERT" in member_names;
    assert "EXTROVERT" in member_names;
    assert "AMBIVERT" in member_names;

    for member in personality_enum.members {
        assert member.type_info == "int" , f"Member {member.name} should have int type, got {member.type_info}";
    }
}

test "enum with string values extraction" {
    prog = JacProgram();
    prog.compile(fixture_path("enum_with_semstr.jac"));
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";

    assert JacRuntime.program is not None;
    mtir_map = all_mtir();

    func_scope = None;
    for scope in mtir_map {
        if "get_person_info" in scope and "enum_with_semstr" in scope {
            func_scope = scope;
            break;
        }
    }

    assert func_scope is not None;
    func_info = mtir_map[func_scope];
    assert isinstance(func_info, FunctionInfo);
    assert isinstance(func_info.return_type, ClassInfo);

    person_class = func_info.return_type;

    status_field = None;
    for field in person_class.fields {
        if field.name == "status" {
            status_field = field;
            break;
        }
    }

    assert status_field is not None , "Person should have status field";
    assert isinstance(status_field.type_info, EnumInfo);

    status_enum = status_field.type_info;
    assert status_enum.name == "Status";
    assert len(status_enum.members) == 3;

    member_names = [m.name for m in status_enum.members];
    assert "PENDING" in member_names;
    assert "ACTIVE" in member_names;
    assert "COMPLETED" in member_names;

    for member in status_enum.members {
        assert member.type_info == "str" , f"Member {member.name} should have str type, got {member.type_info}";
    }
}

test "enum without values extraction" {
    prog = JacProgram();
    prog.compile(fixture_path("enum_no_value.jac"));
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";

    assert JacRuntime.program is not None;
    mtir_map = all_mtir();

    func_scope = None;
    for scope in mtir_map {
        if "yes_or_no" in scope and "enum_no_value" in scope {
            func_scope = scope;
            break;
        }
    }

    assert func_scope is not None , "Should find yes_or_no function";
    func_info = mtir_map[func_scope];
    assert isinstance(func_info, FunctionInfo);

    assert isinstance(func_info.return_type, EnumInfo) , f"Expected EnumInfo, got {type(
        func_info.return_type
    )}";

    tell_enum = func_info.return_type;
    assert tell_enum.name == "Tell";
    assert len(tell_enum.members) == 2;

    member_names = [m.name for m in tell_enum.members];
    assert "YES" in member_names;
    assert "NO" in member_names;

    for member in tell_enum.members {
        assert member.type_info is None , f"Member {member.name} without value should have None type, got {member.type_info}";
    }
}

test "enum semstrings are extracted" {
    prog = JacProgram();
    prog.compile(fixture_path("enum_with_semstr.jac"));
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";

    assert JacRuntime.program is not None;
    mtir_map = all_mtir();

    func_scope = None;
    for scope in mtir_map {
        if "get_person_info" in scope and "enum_with_semstr" in scope {
            func_scope = scope;
            break;
        }
    }

    assert func_scope is not None;
    func_info = mtir_map[func_scope];
    assert isinstance(func_info, FunctionInfo);
    assert isinstance(func_info.return_type, ClassInfo);

    person_class = func_info.return_type;

    personality_field = next(
        (
            f
            for f in person_class.fields
            if f.name == "personality"
        ),
        None
    );
    assert personality_field is not None;
    assert isinstance(personality_field.type_info, EnumInfo);

    personality_enum = personality_field.type_info;

    introvert = next(
        (
            m
            for m in personality_enum.members
            if m.name == "INTROVERT"
        ),
        None
    );
    assert introvert is not None;
    assert introvert.semstr is not None;
    assert (
        "reserved" in introvert.semstr.lower()
        or "reflective" in introvert.semstr.lower()
    );

    extrovert = next(
        (
            m
            for m in personality_enum.members
            if m.name == "EXTROVERT"
        ),
        None
    );
    assert extrovert is not None;
    assert extrovert.semstr is not None;
    assert (
        "outgoing" in extrovert.semstr.lower()
        or "interaction" in extrovert.semstr.lower()
    );
}

test "enum in schema generation" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;

    try {
        jac_import("enum_with_semstr", base_path=FIXTURE_DIR + "/");

        import from enum_with_semstr { Person }
        import jaclang.byllm.schema as schema;

        person_schema = schema.type_to_schema(Person, info=None);

        assert "json_schema" in person_schema;
        assert "schema" in person_schema["json_schema"];
        inner_schema = person_schema["json_schema"]["schema"];

        assert "properties" in inner_schema;
        assert "personality" in inner_schema["properties"];

        personality_schema = inner_schema["properties"]["personality"];

        assert "type" in personality_schema;
        assert personality_schema["type"] == "integer";

        assert "description" in personality_schema;
        desc = personality_schema["description"];
        assert "INTROVERT" in desc or "EXTROVERT" in desc or "AMBIVERT" in desc;
        assert "[1, 2, 3]" in desc or "1" in desc;

        assert "status" in inner_schema["properties"];
        status_schema = inner_schema["properties"]["status"];
        assert status_schema["type"] == "string";
        assert "PENDING" in status_schema["description"];
    } finally {
        sys.stdout = sys.__stdout__;
    }
}

# =============================================================================
# Scope Resolution Consistency Tests (Runtime vs Compile-time)
# =============================================================================
test "same function name different files resolve distinctly" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;

    try {
        jac_import("scope_main", base_path=FIXTURE_DIR + "/");
    } finally {
        sys.stdout = sys.__stdout__;
    }

    assert JacRuntime.program is not None;
    mtir_map = all_mtir();

    process_data_scopes = [
        scope
        for scope in mtir_map
        if "process_data" in scope
    ];

    assert len(process_data_scopes) >= 2 , f"Expected at least 2 process_data scopes (one per module), found: {process_data_scopes}";

    alpha_scope = [
        s
        for s in process_data_scopes
        if "module_alpha" in s
    ];
    beta_scope = [
        s
        for s in process_data_scopes
        if "module_beta" in s
    ];

    assert len(alpha_scope) == 1 , f"Expected exactly one module_alpha.process_data scope, found: {alpha_scope}";
    assert len(beta_scope) == 1 , f"Expected exactly one module_beta.process_data scope, found: {beta_scope}";

    assert alpha_scope[0] != beta_scope[0] , "Alpha and beta scopes should be different";

    alpha_info = mtir_map[alpha_scope[0]];
    beta_info = mtir_map[beta_scope[0]];

    assert isinstance(alpha_info, FunctionInfo);
    assert isinstance(beta_info, FunctionInfo);
    assert alpha_info.return_type.name == "AlphaResult";
    assert beta_info.return_type.name == "BetaResult";
}

test "imported packaged module resolves via fetch_mtir" {
    # Was: assert the import rekey produced fullname keys in a flat mtir_map.
    # Now: the flat map and rekey are gone. fetch_mtir resolves an imported
    # packaged module's by-LLM function through filesystem identity alone
    # (mtir_module_key of the module's __file__), proving cleanup key ==
    # storage key == lookup key with no key-space bridge to maintain.
    import from jaclang.jac0core.mtp { fetch_mtir }

    for name in [
        "scope_main",
        "scope_dir.module_alpha",
        "scope_dir.module_beta",
        "scope_dir"
    ] {
        sys.modules.pop(name, None);
    }

    captured_output = io.StringIO();
    sys.stdout = captured_output;
    try {
        jac_import("scope_main", base_path=FIXTURE_DIR + "/");
    } finally {
        sys.stdout = sys.__stdout__;
    }

    alpha_mod = sys.modules.get("scope_dir.module_alpha");
    beta_mod = sys.modules.get("scope_dir.module_beta");
    assert alpha_mod is not None , "scope_dir.module_alpha should be imported";
    assert beta_mod is not None , "scope_dir.module_beta should be imported";

    alpha_fn = alpha_mod?.process_data;
    beta_fn = beta_mod?.process_data;
    assert alpha_fn is not None and beta_fn is not None;

    alpha_info = fetch_mtir(alpha_fn);
    beta_info = fetch_mtir(beta_fn);
    assert alpha_info is not None , "fetch_mtir should resolve module_alpha.process_data";
    assert beta_info is not None , "fetch_mtir should resolve module_beta.process_data";
    assert isinstance(alpha_info, FunctionInfo);
    assert isinstance(beta_info, FunctionInfo);
    assert alpha_info.return_type.name == "AlphaResult";
    assert beta_info.return_type.name == "BetaResult";
}

test "runtime scope resolution matches compile time" {
    prog = JacProgram();
    fixture = fixture_path("basic_compile.jac");
    prog.compile(fixture);
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";

    assert JacRuntime.program is not None;
    mtir_map = all_mtir();

    expected_stem = Path(fixture).stem;

    matching_scopes = [
        scope
        for scope in mtir_map
        if scope.startswith(f"{expected_stem}.")
    ];

    assert len(matching_scopes) > 0 , f"Should find scopes starting with '{expected_stem}.'. Available scopes: {list(
        mtir_map.keys()
    )}";

    runtime_stem = expected_stem;

    for scope in matching_scopes {
        module_part = scope.split(".")[0];
        assert module_part == runtime_stem , f"Scope '{scope}' module part '{module_part}' doesn't match expected runtime stem '{runtime_stem}'";
    }
}

test "scope portable across paths" {
    prog = JacProgram();
    fixture = fixture_path("basic_compile.jac");
    prog.compile(fixture);
    assert not prog.errors_had;

    assert JacRuntime.program is not None;
    mtir_map = all_mtir();

    for scope in mtir_map {
        assert not scope.startswith("/") , f"Scope '{scope}' should not start with absolute path";
        assert ":\\" not in scope and ":/" not in scope , f"Scope '{scope}' should not contain Windows drive letters";
        module_part = scope.split(".")[0];
        assert "/" not in module_part and "\\" not in module_part , f"Module part '{module_part}' should not contain path separators";
    }
}

test "invalidate module makes runtime lookup return None" {
    # Regression for the dual-map desync: invalidating a module must clear its
    # MTIR from the single store so the runtime lookup (fetch_mtir) returns
    # None. One store keyed by filesystem identity means cleanup key ==
    # storage key == lookup-resolved key, so a stale lookup is impossible.
    import shutil;
    import from jaclang.jac0core.jir { get_module_cache_path }
    import from jaclang.jac0core.mtp { fetch_mtir }

    tmp_path = Path(tempfile.mkdtemp());
    mod_file = tmp_path / "leaked.jac";
    shutil.copy(fixture_path("basic_compile.jac"), str(mod_file));
    mod_path = str(mod_file.resolve());

    assert JacRuntime.program is not None;
    prog = JacRuntime.program;
    try {
        jac_import("leaked", base_path=str(tmp_path) + "/");
        leaked_mod = sys.modules.get("leaked");
        assert leaked_mod is not None , "leaked module should execute on import";

        fn = leaked_mod?.generate_person;
        assert fn is not None , "leaked module should expose generate_person";
        assert fetch_mtir(fn) is not None , (
            "fetch_mtir should resolve before invalidation"
        );

        prog.invalidate_module(mod_path);

        assert fetch_mtir(fn) is None , (
            "fetch_mtir must return None once the module's MTIR is invalidated"
        );
    } finally {
        sys.modules.pop("leaked", None);
        cache_path = get_module_cache_path(mod_path);
        if cache_path.exists() {
            cache_path.unlink();
        }
        shutil.rmtree(str(tmp_path), ignore_errors=True);
    }
}
