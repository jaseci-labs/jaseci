from jaclang import JacMachine as Jac

(mod,) = Jac.jac_import(target=".simple_walk", base_path=__file__)
mod.test_run()
