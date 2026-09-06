import os;
import type from jaclang.compiler.driver.program { JacProgram }
import type from jaclang.compiler.frontend.codeinfo { CodeGenTarget }
import type from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.driver.jir {
    NativeStamp,
    SEC_NCTDEPS,
    ct_deps_section,
    ct_dep_text_fresh,
    SEC_NBITCODE,
    SEC_NIFACE,
    SEC_NOBJ,
    SEC_MODKEY,
    SEC_PLACEMENT,
    cache_mode,
    current_native_stamp,
    get_module_cache_path,
    is_module_cache_valid,
    jir_cacheable_source_path,
    module_cache_key,
    native_section_payload,
    read_native_dep_hashes,
    read_section_bytes,
    read_sections_blob,
    write_sections
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.native_iface { NativeIface }

def compiler_package_parent -> str {
    """The directory holding the `jaclang` package this process runs: what a
child must put first on its path to run the same compiler. A build boots
its interpreter with `-I` and an explicit `sys.path`, which a child does
not inherit, and `python -c` would otherwise put the working directory
first, where a checkout's own `jaclang` shadows the tree being built.""";
    import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }
    return os.path.dirname(jaclang_pkg_root());
}

def child_compiler_argv(code: str, args: list[str]) -> list[str] {
    """The command line of a child compiler process: this interpreter, safe
path mode so the working directory never joins `sys.path`, the driver
code, its arguments, and the package parent for the driver to insert
first. `import jaclang` registers the `.jac` importer itself.""";
    import sys;
    return [sys.executable, "-P", "-c", code]
        + list(args)
        + [compiler_package_parent()];
}

def child_compiler_env(extra: (dict[str, str] | None) = None) -> dict[str, str] {
    env = dict(os.environ);
    pkg_parent = compiler_package_parent();
    prior = env.get("PYTHONPATH", "");
    parts = [pkg_parent] + ([prior] if prior else []);
    env["PYTHONPATH"] = os.pathsep.join(parts);
    if extra {
        env.update(extra);
    }
    return env;
}

glob _UNITS_IN_FLIGHT: set[str] = set(),
     UNIT_CHILD_DEPTH_ENV: str = "JAC_NATIVE_UNIT_DEPTH",
     UNIT_ISOLATE_ENV: str = "JAC_NATIVE_UNIT_ISOLATE",
     UNIT_CHILD_MAX_DEPTH: int = 2;

def unit_isolation_wanted -> bool {
    return os.environ.get(UNIT_ISOLATE_ENV, "") not in ("", "0");
}

glob _UNIT_CHILD_DRIVER: str = (
         "import json, sys\n"
         "sys.path.insert(0, sys.argv[-1])\n"
         "from jaclang.compiler.driver.program import JacProgram\n"
         "from jaclang.compiler.driver.compile_options import CompileOptions, push_native_target\n"
         "opts = CompileOptions.from_native_import_env(json.loads(sys.argv[2]))\n"
         "push_native_target(opts.native_target or '')\n"
         "reg = JacProgram().native_units()\n"
         "with open(sys.argv[4]) as source:\n"
         "    for path, blob in json.load(source).items():\n"
         "        reg.register_products_blob(path, bytes.fromhex(blob), opts)\n"
         "ent = reg.compile_unit(sys.argv[1], opts)\n"
         "if ent is None:\n"
         "    why = reg.failures.get(sys.argv[1]) or 'no diagnostic was recorded'\n"
         "    sys.stderr.write('jac: native unit ' + sys.argv[1] + ' failed: ' + why + '\\n')\n"
         "    sys.exit(3)\n"
         "open(sys.argv[3], 'wb').write(reg.products_blob(sys.argv[1], opts))\n"
     );

obj NativeUnitEntry {
    has path: str,
        digest: str,
        iface: NativeIface,
        stamp: NativeStamp,
        source: str = "",
        source_key: (str | None) = None,
        object_bytes: (bytes | None) = None,
        bitcode: (bytes | None) = None,
        compile_deps: bytes = b"",
        compile_deps_base: str = "",
        dep_digests: dict[str, str] = {};
}

obj NativeVerdict {
    has demoted: bool = False,
        code: str = "",
        detail: str = "";
}

obj NativeUnitRegistry {
    has prog: JacProgram,
        entries: dict[str, NativeUnitEntry] = {},
        building: set[str] postinit,
        checking: set[str] postinit,
        not_native: dict[str, str] = {},
        failures: dict[str, str] = {},
        compiled_paths: list[str] = [],
        verdicts: dict[str, tuple[str, NativeVerdict]] = {};

    def postinit {
        self.building = set();
        self.checking = set();
    }

    def clear {
        self.entries.clear();
        self.not_native.clear();
        self.verdicts.clear();
        self.compiled_paths.clear();
        self.failures.clear();
    }

    def forget(path: str) {
        real = os.path.realpath(path);
        self.entries.pop(real, None);
        self.not_native.pop(real, None);
        self.failures.pop(real, None);
    }

    static def _source_key(path: str) -> (str | None) {
        try {
            return module_cache_key(path);
        } except OSError {
            return None;
        }
    }

    def _event(name: str) {
        counters = self.prog.analysis.cache_events;
        counters[name] = counters.get(name, 0) + 1;
    }

    def note_codegen(path: str, object_emitted: bool = True) {
        self.compiled_paths.append(os.path.realpath(path));
        self._event("native_unit_codegen");
        if object_emitted {
            self._event("native_object_emit");
        }
    }

    def note_link(reused: bool) {
        self._event("native_link_hit" if reused else "native_link");
    }

    def _options -> CompileOptions {
        opts = self.prog.options;
        return opts if opts is not None else CompileOptions();
    }

    def stamp_for(options: (CompileOptions | None) = None) -> NativeStamp {
        opts = options if options is not None else self._options();
        return current_native_stamp(opts.codegen_identity(), opts.effective_triple());
    }

    def _module_jir(resolved: str) -> (tuple[bytes, str] | None) {
        try {
            cache_path = get_module_cache_path(resolved);
            if is_module_cache_valid(resolved, cache_path) {
                return (cache_path.read_bytes(), "", );
            }
        } except Exception {}
        try {
            return self.prog._get_compiler()._sealed_jir_data(resolved);
        } except Exception {
            return None;
        }
    }

    def _entry_fresh(ent: NativeUnitEntry) -> bool {
        """Use the shared source key, including annex membership and content.
        A deleted file differs from a unit that never had a source file.""";
        return ent.source_key == NativeUnitRegistry._source_key(ent.path)
            and ct_dep_text_fresh(
                ent.compile_deps.decode("utf-8"), ent.compile_deps_base
            );
    }

    def _register(
        resolved: str, iface: NativeIface, stamp: NativeStamp, source: str
    ) -> NativeUnitEntry {
        ent = NativeUnitEntry(
            path=resolved,
            digest=iface.digest(),
            iface=iface,
            stamp=stamp,
            source=source,
            source_key=NativeUnitRegistry._source_key(resolved)
        );
        self.entries[resolved] = ent;
        return ent;
    }

    def record(
        path: str,
        iface: NativeIface,
        options: (CompileOptions | None) = None,
        dep_digests: (dict[str, str] | None) = None,
        compile_deps: bytes = b""
    ) -> NativeUnitEntry {
        resolved = os.path.realpath(path);
        ent = self._register(resolved, iface, self.stamp_for(options), "compile");
        ent.compile_deps = compile_deps;
        ent.dep_digests = dict(dep_digests or {});
        gen = self._live_gen(resolved);
        if gen is not None {
            ent.object_bytes = gen.native_object;
            ent.bitcode = gen.native_bitcode;
        }
        return ent;
    }

    def record_module(
        module: Module, options: (CompileOptions | None) = None
    ) -> (NativeUnitEntry | None) {
        """A module this process just lowered enters the registry with the
        digests of the dependencies it was lowered against, which are the
        entries those dependencies registered before it.""";
        if not (module?.loc and module.loc.mod_path) {
            return None;
        }
        gen = module.gen;
        if gen.native_iface is None {
            return None;
        }
        ent = self.record(
            module.loc.mod_path,
            gen.native_iface,
            options,
            dep_digests=self.dep_digests(list(gen.native_deps or [])),
            compile_deps=ct_deps_section(module.ct_file_deps, module.ct_body_deps)
        );
        ent.object_bytes = gen.native_object;
        ent.bitcode = gen.native_bitcode;
        return ent;
    }

    def recorded_native_deps(
        path: str, options: (CompileOptions | None) = None
    ) -> list[tuple[str, str]] {
        resolved = os.path.realpath(path);
        live = self.entries.get(resolved);
        if live is not None and live.stamp.matches(self.stamp_for(options)) {
            return sorted(live.dep_digests.items());
        }
        found = self._module_jir(resolved);
        if found is None {
            return [];
        }
        return read_native_dep_hashes(
            found[0], self.stamp_for(options), found[1], resolved
        );
    }

    def _deps_match(
        data: bytes,
        stamp: NativeStamp,
        base_dir: str,
        anchor: str = "",
        options: (CompileOptions | None) = None
    ) -> bool {
        for (dep, recorded) in read_native_dep_hashes(data, stamp, base_dir, anchor) {
            ent = self.ensure(dep, compile_on_miss=False, options=options);
            if ent is None or ent.digest != recorded {
                return False;
            }
        }
        return True;
    }

    def dep_digests(paths: list[str]) -> dict[str, str] {
        out: dict[str, str] = {};
        for p in paths {
            real = os.path.realpath(p);
            out[real] = self.known_digest(real);
        }
        return out;
    }

    def _read_from_disk(
        resolved: str,
        stamp: NativeStamp,
        check_deps: bool,
        options: (CompileOptions | None) = None
    ) -> (NativeUnitEntry | None) {
        found = self._module_jir(resolved);
        if found is None {
            return None;
        }
        (data, base_dir) = found;
        payload = native_section_payload(read_section_bytes(data, SEC_NIFACE), stamp);
        iface = NativeIface.from_bytes(payload);
        if iface is None {
            return None;
        }
        compile_deps = native_section_payload(
            read_section_bytes(data, SEC_NCTDEPS), stamp
        );
        if compile_deps is None
            or not ct_dep_text_fresh(compile_deps.decode("utf-8"), base_dir) {
            self._event("native_comptime_miss");
            return None;
        }
        iface.resolve_deps(resolved);
        if check_deps
            and not self._deps_match(data, stamp, base_dir, resolved, options) {
            self._event("native_dep_miss");
            return None;
        }
        ent = self._register(resolved, iface, stamp, "disk");
        ent.compile_deps = compile_deps;
        ent.compile_deps_base = base_dir;
        ent.dep_digests = dict(read_native_dep_hashes(data, stamp, base_dir, resolved));
        ent.object_bytes = native_section_payload(
            read_section_bytes(data, SEC_NOBJ), stamp
        );
        ent.bitcode = native_section_payload(
            read_section_bytes(data, SEC_NBITCODE), stamp
        );
        return ent;
    }

    def ensure(
        path: str,
        compile_on_miss: bool = True,
        options: (CompileOptions | None) = None,
        check_deps: bool = True
    ) -> (NativeUnitEntry | None) {
        resolved = os.path.realpath(path);
        if not jir_cacheable_source_path(resolved) {
            return None;
        }
        stamp = self.stamp_for(options);
        ent = self.entries.get(resolved);
        if ent is not None and ent.stamp.matches(stamp) and self._entry_fresh(ent) {
            return ent;
        }
        if ent is not None {
            del self.entries[resolved];
        }
        if resolved in self.building {
            return None;
        }
        if resolved in self.checking {
            return self._read_from_disk(
                resolved, stamp, check_deps=False, options=options
            );
        }
        (rebuild, _) = cache_mode();
        if not rebuild {
            self.checking.add(resolved);
            try {
                found = self._read_from_disk(
                    resolved, stamp, check_deps=check_deps, options=options
                );
            } finally {
                self.checking.discard(resolved);
            }
            if found is not None {
                self._event("native_iface_hit");
                return found;
            }
        }
        if not compile_on_miss or not os.path.isfile(resolved) {
            return None;
        }
        if self.not_native.get(resolved) == NativeUnitRegistry._source_key(resolved) {
            return None;
        }
        return self.compile_unit(resolved, options);
    }

    def read_unit(
        path: str, options: (CompileOptions | None) = None
    ) -> (NativeUnitEntry | None) {
        resolved = os.path.realpath(path);
        self.entries.pop(resolved, None);
        return self._read_from_disk(
            resolved, self.stamp_for(options), check_deps=False, options=options
        );
    }

    def known_native_deps(path: str, native_unit_compile: bool = False) -> list[str] {
        resolved = os.path.realpath(path);
        ent = self.entries.get(resolved);
        if ent is not None {
            return sorted(os.path.realpath(d) for d in ent.iface.deps);
        }
        found = self._module_jir(resolved);
        if found is None {
            return [];
        }
        (data, base_dir) = found;
        unpacked = NativeStamp.unpack(read_section_bytes(data, SEC_NIFACE));
        if unpacked is not None {
            iface = NativeIface.from_bytes(unpacked[1]);
            if iface is not None {
                iface.resolve_deps(resolved);
                return sorted(os.path.realpath(d) for d in iface.deps);
            }
        }
        import from jaclang.compiler.driver.jir { read_dep_rows }
        import from jaclang.compiler.placement.placement_facts { native_unit }
        out: list[str] = [];
        for row in read_dep_rows(data, base_dir) {
            dep = os.path.realpath(row.path);
            if dep.endswith(".jac")
                and os.path.isfile(dep)
                and native_unit(dep, native_unit_compile, self.prog) {
                out.append(dep);
            }
        }
        return sorted(set(out));
    }

    def compile_unit_detached(
        path: str, options: (CompileOptions | None) = None, use_str: (str | None) = None
    ) -> (NativeUnitEntry | None) {
        import json;
        import subprocess;
        import sys;
        resolved = os.path.realpath(path);
        base = options if options is not None else self._options();
        depth = int(os.environ.get(UNIT_CHILD_DEPTH_ENV, "0") or "0");
        if use_str is not None
            or depth >= UNIT_CHILD_MAX_DEPTH
            or not unit_isolation_wanted() {
            """A program's few units compile in this process; a child per
            unit is for the plans that compile the compiler itself, where
            what each compile leaves behind adds up across dozens of units.""";
            return self.compile_unit(resolved, base, use_str);
        }
        child_env = child_compiler_env({UNIT_CHILD_DEPTH_ENV: str(depth + 1)});
        env = json.dumps(base.clone_for_native_import().native_import_env());
        self._event("native_unit_compile_detached");
        import tempfile;
        (fd, products) = tempfile.mkstemp(prefix="jac-unit-", suffix=".jirx");
        os.close(fd);
        (fd, dependencies) = tempfile.mkstemp(prefix="jac-unit-deps-", suffix=".json");
        os.close(fd);
        try {
            with open(dependencies, "w", encoding="utf-8") as snapshot {
                json.dump(
                    {
                        ent.path: self.products_blob(
                            ent.path, base, include_code=False
                        ).hex() for ent in self._prepared_entries(resolved, base)
                    },
                    snapshot
                );
            }
            import from jaclang.compiler.driver.compile_options { env_na_debug }
            quiet = not env_na_debug();
            try {
                proc = subprocess.run(
                    child_compiler_argv(
                        _UNIT_CHILD_DRIVER, [resolved, env, products, dependencies]
                    ),
                    env=child_env,
                    capture_output=quiet,
                    text=quiet
                );
            } except OSError as exc {
                self.failures[resolved] = f"{type(exc).__name__}: {exc}";
                return None;
            }
            if proc.returncode != 0 {
                """A unit's seam warnings are its own business while it lowers;
                they reach the terminal only when the child fails, so a first
                run that derives a kernel does not scroll its diagnostics.""";
                if quiet and proc.stderr {
                    sys.stderr.write(proc.stderr[-4000:]);
                }
                self.failures[resolved] = (
                    f"the unit compile exited with status {proc.returncode}"
                );
                return None;
            }
            try {
                blob = open(products, "rb").read();
            } except OSError {
                blob = b"";
            }
        } finally {
            for temporary in (products, dependencies) {
                try {
                    os.remove(temporary);
                } except OSError {}
            }
        }
        self.forget(resolved);
        found = self.register_products_blob(resolved, blob, base) if blob else None;
        if found is None {
            self.failures[resolved] = "the unit compile handed back no native products";
        }
        return found;
    }

    def _product_sections(
        path: str, options: (CompileOptions | None) = None, include_code: bool = True
    ) -> dict[int, bytes] {
        resolved = os.path.realpath(path);
        ent = self.entries.get(resolved);
        if ent is None {
            return {};
        }
        import from jaclang.compiler.driver.jir {
            SEC_NDEPS,
            native_deps_section,
            absolutize_ct_deps_section
        }
        stamp = self.stamp_for(options);
        sections: dict[int, bytes] = {
            SEC_NCTDEPS: stamp.pack(
                absolutize_ct_deps_section(ent.compile_deps, ent.compile_deps_base)
            ),
            SEC_NIFACE: stamp.pack(ent.iface.to_bytes()),
            SEC_NDEPS: stamp.pack(native_deps_section(ent.dep_digests))
        };
        if ent.source_key is not None {
            sections[SEC_MODKEY] = ent.source_key.encode("utf-8");
        }
        if include_code and ent.object_bytes is not None {
            sections[SEC_NOBJ] = stamp.pack(ent.object_bytes);
        }
        if include_code and ent.bitcode is not None {
            sections[SEC_NBITCODE] = stamp.pack(ent.bitcode);
        }
        return sections;
    }

    def products_blob(
        path: str, options: (CompileOptions | None) = None, include_code: bool = True
    ) -> bytes {
        sections = self._product_sections(path, options, include_code);
        return write_sections(sections) if sections else b"";
    }

    def register_products_blob(
        resolved: str, blob: bytes, options: (CompileOptions | None) = None
    ) -> (NativeUnitEntry | None) {
        import from jaclang.compiler.driver.jir { SEC_NDEPS }
        stamp = self.stamp_for(options);
        sections = read_sections_blob(blob);
        source_key = sections.get(SEC_MODKEY);
        if source_key is not None
            and source_key.decode("utf-8")
                != NativeUnitRegistry._source_key(resolved) {
            return None;
        }
        iface = NativeIface.from_bytes(
            native_section_payload(sections.get(SEC_NIFACE), stamp)
        );
        if iface is None {
            return None;
        }
        iface.resolve_deps(resolved);
        deps_raw = native_section_payload(sections.get(SEC_NDEPS), stamp);
        recorded: dict[str, str] = {};
        if deps_raw {
            import from jaclang.compiler.driver.jir { parse_native_dep_rows }
            for (dep, digest) in parse_native_dep_rows(deps_raw, resolved) {
                recorded[dep] = digest;
            }
        }
        import from jaclang.compiler.frontend.codeinfo { CodeGenTarget }
        carrier = self.prog.hub.artifacts.get(resolved);
        if carrier is None {
            carrier = CodeGenTarget();
            self.prog.hub.artifacts[resolved] = carrier;
        }
        carrier.native_iface = iface;
        carrier.native_object = native_section_payload(sections.get(SEC_NOBJ), stamp);
        carrier.native_bitcode = native_section_payload(
            sections.get(SEC_NBITCODE), stamp
        );
        ent = self._register(resolved, iface, stamp, "child");
        ent.compile_deps = native_section_payload(sections.get(SEC_NCTDEPS), stamp)
            or b"";
        ent.dep_digests = recorded;
        ent.object_bytes = carrier.native_object;
        ent.bitcode = carrier.native_bitcode;
        return ent;
    }

    def _prepared_entries(path: str, options: CompileOptions) -> list[NativeUnitEntry] {
        stamp = self.stamp_for(options);
        return [
            ent
            for (dep, ent) in self.entries.items()
            if dep != path and ent.stamp.matches(stamp) and self._entry_fresh(ent)
        ];
    }

    def compile_unit(
        path: str, options: (CompileOptions | None) = None, use_str: (str | None) = None
    ) -> (NativeUnitEntry | None) {
        resolved = os.path.realpath(path);
        if resolved in self.building or resolved in _UNITS_IN_FLIGHT {
            return None;
        }
        base = options if options is not None else self._options();
        self.building.add(resolved);
        _UNITS_IN_FLIGHT.add(resolved);
        mod: any = None;
        try {
            self._event("native_unit_compile");
            import from jaclang.compiler.driver.program { JacProgram }
            import copy;
            unit_prog = JacProgram();
            unit_registry = unit_prog.native_units();
            for known in self._prepared_entries(resolved, base) {
                unit_registry.entries[known.path] = copy.copy(known);
            }
            try {
                mod = unit_prog.compile(
                    resolved, use_str=use_str, options=base.clone_for_native_import()
                );
            } finally {
                if unit_prog.errors_had {
                    self.failures[resolved] = "\n".join(
                        e.pretty_print() for e in unit_prog.errors_had[:5]
                    );
                }
            }
        } except Exception as exc {
            import traceback;
            self.failures[resolved] = (
                f"{type(exc).__name__}: {exc}"
                + (f" ({self.failures[resolved]})" if resolved in self.failures else "")
            );
            import from jaclang.compiler.driver.compile_options { env_na_debug }
            if env_na_debug() {
                import sys;
                sys.stderr.write(f"NA_DEBUG native unit {resolved} raised:\n");
                sys.stderr.write(traceback.format_exc());
                sys.stderr.write("NA_DEBUG requested from:\n");
                sys.stderr.write("".join(traceback.format_stack(limit=30)));
            }
            return None;
        } finally {
            self.building.discard(resolved);
            _UNITS_IN_FLIGHT.discard(resolved);
        }
        iface = mod.gen.native_iface if (mod is not None and mod.gen) else None;
        self.compiled_paths.extend(unit_prog.native_units().compiled_paths);
        if iface is None {
            found = self.entries.get(resolved);
            if found is None {
                key = NativeUnitRegistry._source_key(resolved);
                if key is not None {
                    self.not_native[resolved] = key;
                }
            }
            return found;
        }
        self.not_native.pop(resolved, None);
        gen = mod.gen;
        if use_str is not None {
            unit_prog.native_units().record_module(mod, base);
        }
        ent = self._register(resolved, iface, self.stamp_for(base), "compile");
        ent.compile_deps = ct_deps_section(mod.ct_file_deps, mod.ct_body_deps);
        ent.dep_digests = dict(
            unit_prog.native_units().recorded_native_deps(resolved, base)
        );
        self._stash_products(resolved, gen);
        try {
            unit_prog.release_compile_closure(collect=False);
            if not _UNITS_IN_FLIGHT {
                shared = unit_prog._get_compiler().selfhost.peek_program();
                if shared is not None and shared is not unit_prog {
                    shared.scrub_hub_types();
                }
            }
        } except Exception {}
        return ent;
    }

    def _stash_products(resolved: str, gen: CodeGenTarget) {
        ent = self.entries.get(resolved);
        if ent is not None {
            ent.object_bytes = gen.native_object;
            ent.bitcode = gen.native_bitcode;
        }
        import from jaclang.compiler.frontend.codeinfo { CodeGenTarget }
        carrier = self.prog.hub.artifacts.get(resolved);
        if carrier is None {
            carrier = CodeGenTarget();
            self.prog.hub.artifacts[resolved] = carrier;
        }
        carrier.native_iface = gen.native_iface;
        carrier.native_object = gen.native_object;
        carrier.native_bitcode = gen.native_bitcode;
        carrier.native_layout = gen.native_layout;
        carrier.native_deps = list(gen.native_deps or []);
    }

    def known_digest(path: str) -> str {
        resolved = os.path.realpath(path);
        ent = self.entries.get(resolved);
        if ent is not None {
            return ent.digest;
        }
        found = self._module_jir(resolved);
        import from jaclang.compiler.driver.compile_options { env_na_debug }
        if found is None {
            if env_na_debug() {
                import sys;
                sys.stderr.write(
                    f"NA_DEBUG known_digest {resolved}: no valid module cache entry\n"
                );
            }
            return "";
        }
        raw = read_section_bytes(found[0], SEC_NIFACE);
        payload = native_section_payload(raw, self.stamp_for());
        if payload is None and env_na_debug() {
            import sys;
            have = NativeStamp.unpack(raw);
            sys.stderr.write(
                f"NA_DEBUG known_digest {resolved}: "
                    + (
                        "no native interface section"
                            if have is None
                            else f"stamp mismatch: disk {have[0].compiler_digest[:12]}/{have[
                                0
                            ].codegen_identity}/{have[0].triple} want {self.stamp_for().compiler_digest[:12]}/{self.stamp_for().codegen_identity}/{self.stamp_for().triple}"
                    )
                    + "\n"
            );
        }
        return NativeIface.read_digest(payload) or "";
    }

    def object_for(
        path: str, options: (CompileOptions | None) = None
    ) -> (bytes | None) {
        ent = self.ensure(path, options=options, check_deps=False);
        if ent is not None and ent.object_bytes is None {
            if ent.bitcode is None {
                ent = self.compile_unit(path, options);
            }
            if ent is not None and ent.bitcode is not None {
                import from jaclang.compiler.backends.native.na_compile_pass {
                    emit_unit_object
                }
                import from jaclang.compiler.driver.jir { write_module_cache }
                opts = options if options is not None else self._options();
                ent.object_bytes = emit_unit_object(ent.bitcode, opts);
                self._event("native_object_emit");
                write_module_cache(
                    ent.path,
                    None,
                    extra_sections=self._product_sections(ent.path, opts)
                );
            }
        }
        return ent.object_bytes if ent is not None else None;
    }

    def bitcode_for(
        path: str, options: (CompileOptions | None) = None
    ) -> (bytes | None) {
        ent = self.ensure(path, options=options, check_deps=False);
        if ent is not None and ent.bitcode is None {
            ent = self.compile_unit(path, options);
        }
        return ent.bitcode if ent is not None else None;
    }

    def _live_gen(resolved: str) -> (CodeGenTarget | None) {
        mod = self.prog.find_module(resolved);
        if mod is not None
            and mod.gen is not None
            and mod.gen.native_iface is not None {
            return mod.gen;
        }
        return self.prog.hub.artifacts.get(resolved);
    }

    def verdict_for(path: str) -> (NativeVerdict | None) {
        resolved = os.path.realpath(path);
        key = NativeUnitRegistry._source_key(resolved);
        cached = self.verdicts.get(resolved);
        if cached is not None {
            if cached[0] == key {
                return cached[1];
            }
            del self.verdicts[resolved];
        }
        found = self._module_jir(resolved);
        if found is None {
            return None;
        }
        verdict = verdict_from_jir(found[0]);
        if verdict is not None and key is not None {
            self.verdicts[resolved] = (key, verdict, );
        }
        return verdict;
    }

    def is_demoted(path: str) -> bool {
        v = self.verdict_for(path);
        return v is not None and v.demoted;
    }

    def demoted_code(path: str) -> str {
        v = self.verdict_for(path);
        return v.code if v is not None else "";
    }

    def record_verdict(path: str, code: str, detail: str) {
        resolved = os.path.realpath(path);
        key = NativeUnitRegistry._source_key(resolved);
        if key is not None {
            self.verdicts[resolved] = (
                key,
                NativeVerdict(demoted=True, code=code, detail=detail),

            );
        }
        import from jaclang.compiler.placement.placement { note_native_verdict }
        note_native_verdict(self.prog, resolved, code, detail);
        self.entries.pop(resolved, None);
    }
}

def verdict_from_jir(data: bytes) -> (NativeVerdict | None) {
    raw = read_section_bytes(data, SEC_PLACEMENT);
    if raw is None {
        return None;
    }
    import from jaclang.compiler.placement.placement { summary_from_bytes }
    summary = summary_from_bytes(raw);
    if summary is None or not summary.native_verdict {
        return None;
    }
    return NativeVerdict(
        demoted=True, code=summary.native_verdict_code, detail=summary.native_verdict
    );
}

def read_native_verdict(path: str) -> (NativeVerdict | None) {
    resolved = os.path.realpath(path);
    try {
        cache_path = get_module_cache_path(resolved);
        if not is_module_cache_valid(resolved, cache_path) {
            return None;
        }
        return verdict_from_jir(cache_path.read_bytes());
    } except Exception {
        return None;
    }
}
