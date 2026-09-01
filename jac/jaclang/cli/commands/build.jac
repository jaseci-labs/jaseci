import from jaclang.comptime { name as ct_name }
import from jaclang.cli.command { Arg, ArgKind, CommandSpec }


comptime SPEC_BUILD: CommandSpec = CommandSpec(
         name="build",
         help="Build a sealed .jab artifact (type-checks first)",
         args=[
             Arg.create(
                 "filename",
                 kind=ArgKind.POSITIONAL,
                 `default="",
                 help="Entry .jac file (default: [project] entry-point from jac.toml)"
             ),
             Arg.create(
                 "as",
                 dest="projection",
                 `default="jab",
                 choices=[
                     "jab",
                     "sealed",
                     "binary",
                     "wheel",
                     "npm",
                     "source",
                     "native"
                 ],
                 help=(
                     "What to emit: 'jab' (single-file sealed app bundle, default), "
                     "'sealed' (unpacked image dir), 'binary' (self-contained "
                     "executable), 'wheel' (PyPI), 'npm' (tarball), 'source' "
                     "(ejected FastAPI+JS tree), 'native' (AOT native binary)"
                 )
             ),
             Arg.create(
                 "output",
                 `default="dist",
                 help="Output directory for the built artifact",
                 short="o"
             ),
             Arg.create(
                 "fat",
                 typ=bool,
                 `default=False,
                 help=(
                     "Vendor the Python dependency closure as wheels into the bundle "
                     "(jab/binary only) so it materializes offline, with no PyPI"
                 )
             ),
             Arg.create(
                 "check_only",
                 typ=bool,
                 `default=False,
                 help="Run the gate and emit nothing"
             ),
             Arg.create(
                 "client",
                 typ=str,
                 `default="",
                 help=(
                     "Build a client shell instead of the artifact: web, "
                     "pwa, mobile, desktop (desktop builds a native "
                     "webview app)."
                 ),
                 choices=[
                     "web",
                     "pwa",
                     "static",
                     "mobile",
                     "desktop",
                     "cef",
                     "react-native"
                 ],
                 short=""
             ),
             Arg.create(
                 "platform",
                 typ=str,
                 `default=None,
                 help="Platform for desktop/mobile shells (windows, macos, linux, all, android, ios)",
                 choices=["windows", "macos", "linux", "all", "android", "ios"],
                 short="p"
             ),

         ],
         examples=[
             ("jac build", "Build a single .jab into dist/"),
             ("jac build --as binary", "Build a self-contained executable"),
             ("jac build --fat", "Build a fat jab (Python deps vendored)"),
             ("jac build --as wheel", "Build a PyPI wheel"),
             (
                 "jac build --check_only",
                 "Type-check the whole project without building"
             ),
             ("jac build --client mobile", "Build the mobile client shell"),

         ],
         group="build",
         handler_name=ct_name(build)
     );

def build(
    filename: str = "",
    projection: str = "jab",
    output: str = "dist",
    check_only: bool = False,
    client: str = "",
    platform: str | None = None,
    fat: bool = False
) -> int;
