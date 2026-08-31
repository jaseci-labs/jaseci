import from jaclang.cli.command { Arg, ArgKind, CommandSpec }
import from jaclang.comptime { name as ct_name }


comptime SPEC_CACHE: CommandSpec = CommandSpec(
         name="cache",
         help="Inspect and maintain jac's on-disk cache stores",
         args=[
             Arg.create(
                 "action",
                 kind=ArgKind.POSITIONAL,
                 `default="ls",
                 help="Action: ls, prune, purge"
             ),
             Arg.create(
                 "name",
                 kind=ArgKind.POSITIONAL,
                 `default="",
                 help="Store name (with `purge`: empty just that store)"
             ),
             Arg.create(
                 "all",
                 typ=bool,
                 `default=False,
                 dest="include_exempt",
                 help="With `purge`: also empty prune-exempt stores (models)",
                 short=""
             ),

         ],
         examples=[
             ("jac cache ls", "List every store with size, entries, and path"),
             ("jac cache prune", "Apply each store's retention policy now"),
             ("jac cache purge", "Empty all non-exempt stores"),
             ("jac cache purge modules", "Empty one store by name"),
             ("jac cache purge --all", "Empty every store, models included"),

         ],
         group="tools",
         handler_name=ct_name(cache)
     );

def cache(action: str = "ls", name: str = "", include_exempt: bool = False) -> int;
