import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

@registry.command(
    name="seal",
    help="Seal Jac source into a native artifact through the seal's gate: one module, or the compiler's own served surface",
    hidden=True,
    args=[
        Arg.create(
            "filename",
            kind=ArgKind.POSITIONAL,
            `default="",
            help="Path to the .jac module to seal as its own unit (omit with --compiler)"
        ),
        Arg.create(
            "compiler",
            kind=ArgKind.FLAG,
            `default=False,
            short="",
            help="Seal the running jaclang tree's served surface into the fused libjac_compiler artifact; under [dev] jaclang_source that is the checkout's compiler, so no binary rebuild is needed"
        ),
        Arg.create(
            "output",
            kind=ArgKind.OPTION,
            short="o",
            `default="",
            help="Output directory (default ./jac-seal); artifacts land under <out>/native/<triple>/ and the tree in your checkout is never touched"
        ),
        Arg.create(
            "ir",
            kind=ArgKind.FLAG,
            `default=False,
            short="",
            help="Also write the unit's LLVM IR text next to the artifact (the raw material of the abort-stub scan)"
        ),
        Arg.create(
            "debug",
            kind=ArgKind.FLAG,
            `default=False,
            short="",
            help="Print the full diagnostic behind every demotion (sets JAC_NA_DEBUG=1)"
        ),

    ],
    examples=[
        (
            "jac seal mymod.jac -o out",
            "Seal one module: gate, link, load canary; refuse on any demotion"
        ),
        (
            "jac seal mymod.jac -o out --ir --debug",
            "Same, plus the unit's LLVM IR and the reason behind each demotion"
        ),
        (
            "jac seal --compiler -o /tmp/seal",
            "Seal the compiler's served surface (all gates and canaries), scratch output"
        ),

    ],
    group="transform"
)
def seal(
    filename: str = "",
    compiler: bool = False,
    output: str = "",
    ir: bool = False,
    debug: bool = False
) -> int;
