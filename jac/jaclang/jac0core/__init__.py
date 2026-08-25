"""jac0core - the bootstrap (jac0) tier of the jaclang tree.

Every .jac file under this directory is compiled by jac0 (the seed
transpiler in ``jaclang/jac0.py``) rather than the full Jac compiler,
because the full compiler depends on it. Membership in this tier is
decided by directory placement (``meta_importer._is_bootstrap_jac``)
and mirrored at seal time by the sealer's ``jac0core/`` path test, so
everything the seed-visible code touches has accreted here over time.

The package currently holds several distinct concerns, not just the
compiler core: the bootstrap-critical compiler (parser/, unitree,
constant, codeinfo, passes/, jir, program, compiler, schedules), the
production runtime (runtime, archetype, jaclib, graph_query, the OSP
kernels), codespace placement planning (placement*, service_cut,
prefix_flip), CLI/config tenants (tomlio, cli_boot, treeprinter), the
byllm meaning-typed IR (mtp), and source-text kernel units
(fmt_kernel/osp_kernel/osp_graph, concatenated by kernel_units for the
native linker rather than imported). Issue #8681 tracks dissolving
this package into function-named homes with manifest-declared tier
membership.

Constraint to preserve: jac0core modules may only import the full
compiler (``jaclang.compiler.*``) inside function bodies, never at
module scope -- a hoisted import deadlocks bootstrap.
"""
