from jaclang import JacMachineInterface as _

(help_func,) = _.jac_import(
    target=".helper",
    base_path=__file__,
    items={"help_func": None},
)
