

from jaclang import JacMachineInterface as _

(tool_func,) = _.py_jac_import(
    target="tools",
    base_path=__file__,
    items={"tool_func": None},
)

glob_var_lib = 'pkg_import_lib_py.glob_var_lib'
