"""Special Imports for Jac Code."""

from __future__ import annotations

import importlib
import importlib.util
import os
import site
import sys
import types
from dataclasses import dataclass, field
from os import getcwd, path
from typing import Optional, Union

from jaclang.runtimelib.machine import JacMachineInterface
from jaclang.runtimelib.utils import sys_path_context
from jaclang.utils.helpers import dump_traceback
from jaclang.utils.log import logging

logger = logging.getLogger(__name__)


@dataclass
class ImportPathSpec:
    """Import Specification."""

    target: str
    base_path: str
    absorb: bool
    mdl_alias: Optional[str]
    override_name: Optional[str]
    language: Optional[str]
    items: Optional[dict[str, Union[str, Optional[str]]]]
    dir_path: str = field(init=False)
    file_name: str = field(init=False)
    module_name: str = field(init=False)
    package_path: str = field(init=False)
    caller_dir: str = field(init=False)
    full_target: str = field(init=False)

    def __post_init__(self) -> None:
        self.dir_path, self.file_name = path.split(path.join(*(self.target.split("."))))
        self.module_name = path.splitext(self.file_name)[0]
        self.package_path = self.dir_path.replace(path.sep, ".")
        self.caller_dir = self.get_caller_dir()
        self.full_target = path.abspath(path.join(self.caller_dir, self.file_name))

    def get_caller_dir(self) -> str:
        """Get the directory of the caller."""
        caller_dir = (
            self.base_path
            if path.isdir(self.base_path)
            else path.dirname(self.base_path)
        )
        caller_dir = caller_dir if caller_dir else getcwd()
        chomp_target = self.target
        if chomp_target.startswith("."):
            chomp_target = chomp_target[1:]
            while chomp_target.startswith("."):
                caller_dir = path.dirname(caller_dir)
                chomp_target = chomp_target[1:]
        return path.join(caller_dir, self.dir_path)


@dataclass
class ImportReturn:
    """Import Return Object."""

    ret_mod: types.ModuleType
    ret_items: list[types.ModuleType]
    importer: "Importer"

    def process_items(
        self,
        module: types.ModuleType,
        items: dict[str, Union[str, Optional[str]]],
        lang: Optional[str],
    ) -> None:
        """Process items within a module by handling renaming and potentially loading missing attributes."""

        def handle_item_loading(
            item: types.ModuleType, alias: Union[str, Optional[str]]
        ) -> None:
            if item:
                self.ret_items.append(item)
                setattr(module, name, item)
                if alias and alias != name and not isinstance(alias, bool):
                    setattr(module, alias, item)

        for name, alias in items.items():
            item = getattr(module, name)
            handle_item_loading(item, alias)

    def load_jac_mod_as_item(
        self,
        module: types.ModuleType,
        name: str,
        jac_file_path: str,
    ) -> Optional[types.ModuleType]:
        """Load a single .jac file into the specified module component."""
        from jaclang.runtimelib.machine import JacMachine

        try:
            package_name = (
                f"{module.__name__}.{name}"
                if hasattr(module, "__path__")
                else module.__name__
            )
            if isinstance(self.importer, JacImporter):
                new_module = JacMachine.loaded_modules.get(
                    package_name,
                    self.importer.create_jac_py_module(
                        self.importer.get_sys_mod_name(jac_file_path),
                        module.__name__,
                        jac_file_path,
                    ),
                )
            codeobj = JacMachine.program.get_bytecode(full_target=jac_file_path)
            if not codeobj:
                raise ImportError(f"No bytecode found for {jac_file_path}")

            exec(codeobj, new_module.__dict__)
            return getattr(new_module, name, new_module)
        except ImportError as e:
            logger.error(dump_traceback(e))
            return None


class Importer:
    """Abstract base class for all importers."""

    def __init__(self) -> None:
        """Initialize the Importer object."""
        self.result: Optional[ImportReturn] = None

    def run_import(self, spec: ImportPathSpec) -> ImportReturn:
        """Run the import process."""
        raise NotImplementedError

    def update_sys(self, module: types.ModuleType, spec: ImportPathSpec) -> None:
        """Update sys.modules with the newly imported module."""
        JacMachineInterface.load_module(spec.module_name, module)


class PythonImporter(Importer):
    """Importer for Python modules."""

    def _load_module(self, spec: ImportPathSpec) -> types.ModuleType:
        """Load the requested Python module."""
        if spec.target.startswith("."):
            tgt = spec.target.lstrip(".")
            if "." in tgt:
                tgt = tgt.split(".")[-1]
            full_target = path.normpath(path.join(spec.caller_dir, tgt))
            imp_spec = importlib.util.spec_from_file_location(tgt, full_target + ".py")
            if not (imp_spec and imp_spec.loader):
                raise ImportError(f"Cannot find module {spec.target} at {full_target}")
            module = importlib.util.module_from_spec(imp_spec)
            sys.modules[imp_spec.name] = module
            imp_spec.loader.exec_module(module)
        else:
            module = importlib.import_module(name=spec.target)
        return module

    def _apply_to_main(
        self, module: types.ModuleType, spec: ImportPathSpec, loaded_items: list
    ) -> None:
        """Apply imported items or module to the __main__ namespace."""
        main_module = sys.modules["__main__"]
        if spec.absorb:
            for name in dir(module):
                if not name.startswith("_"):
                    setattr(main_module, name, getattr(module, name))
        elif spec.items:
            for name, alias in spec.items.items():
                alias = name if isinstance(alias, bool) else alias or name
                try:
                    item = getattr(module, name)
                except AttributeError:
                    if hasattr(module, "__path__"):
                        item = importlib.import_module(f"{spec.target}.{name}")
                    else:
                        raise
                if item not in loaded_items:
                    setattr(main_module, alias, item)
                    loaded_items.append(item)
        else:
            setattr(
                main_module,
                spec.mdl_alias if isinstance(spec.mdl_alias, str) else spec.target,
                module,
            )

    def run_import(self, spec: ImportPathSpec) -> ImportReturn:
        """Run the import process for Python modules."""
        loaded_items: list = []
        module = self._load_module(spec)
        self._apply_to_main(module, spec, loaded_items)
        self.result = ImportReturn(module, loaded_items, self)
        return self.result


class JacImporter(Importer):
    """Importer for Jac modules."""

    def get_sys_mod_name(self, full_target: str) -> str:
        """Generate proper module names from file paths."""
        from jaclang.runtimelib.machine import JacMachine

        full_target = os.path.abspath(full_target)

        # If the file is located within a site-packages directory, strip that prefix.
        sp_index = full_target.find("site-packages")
        if sp_index != -1:
            # Remove the site-packages part and any leading separator.
            rel = full_target[sp_index + len("site-packages") :]
            rel = rel.lstrip(os.sep)
        else:
            rel = path.relpath(full_target, start=JacMachine.base_path_dir)
        rel = os.path.splitext(rel)[0]
        if os.path.basename(rel) == "__init__":
            rel = os.path.dirname(rel)
        mod_name = rel.replace(os.sep, ".").strip(".")
        return mod_name

    def handle_directory(
        self, module_name: str, full_mod_path: str
    ) -> types.ModuleType:
        """Import from a directory that potentially contains multiple Jac modules."""
        module_name = self.get_sys_mod_name(full_mod_path)
        module = types.ModuleType(module_name)
        module.__name__ = module_name
        module.__path__ = [full_mod_path]
        module.__file__ = None

        JacMachineInterface.load_module(module_name, module)

        # If the directory contains an __init__.jac, execute it so that the
        # package namespace is populated immediately (mirrors Python's own
        # package behaviour with __init__.py).
        init_jac = os.path.join(full_mod_path, "__init__.jac")
        if os.path.isfile(init_jac):
            from jaclang.runtimelib.machine import JacMachine

            # Point the package's __file__ to the init file for introspection
            module.__file__ = init_jac

            codeobj = JacMachine.program.get_bytecode(full_target=init_jac)
            if not codeobj:
                # Compilation should have provided bytecode for __init__.jac.
                # Raising ImportError here surfaces compile-time issues clearly.
                raise ImportError(f"No bytecode found for {init_jac}")

            try:
                # Ensure the directory is on sys.path while executing so that
                # relative imports inside __init__.jac resolve correctly.
                with sys_path_context(full_mod_path):
                    exec(codeobj, module.__dict__)
            except Exception as e:
                # Log detailed traceback for easier debugging and re-raise.
                logger.error(e)
                logger.error(dump_traceback(e))
                raise e

        return module

    def create_jac_py_module(
        self,
        module_name: str,
        package_path: str,
        full_target: str,
    ) -> types.ModuleType:
        """Create a module."""
        from jaclang.runtimelib.machine import JacMachine

        module = types.ModuleType(module_name)
        module.__file__ = full_target
        module.__name__ = module_name
        if package_path:
            base_path = full_target.split(package_path.replace(".", path.sep))[0]
            parts = package_path.split(".")
            for i in range(len(parts)):
                package_name = ".".join(parts[: i + 1])
                if package_name not in JacMachine.loaded_modules:
                    full_mod_path = path.join(
                        base_path, package_name.replace(".", path.sep)
                    )
                    self.handle_directory(
                        module_name=package_name,
                        full_mod_path=full_mod_path,
                    )
        JacMachineInterface.load_module(module_name, module)
        return module

    def _resolve_target(self, spec: ImportPathSpec) -> None:
        """Resolve the module's full path."""
        jacpaths = os.environ.get("JACPATH", "")
        search_paths = [spec.caller_dir]
        for site_dir in site.getsitepackages():
            if site_dir and site_dir not in search_paths:
                search_paths.append(site_dir)
        user_site = getattr(site, "getusersitepackages", None)
        if user_site:
            user_dir = site.getusersitepackages()
            if user_dir and user_dir not in search_paths:
                search_paths.append(user_dir)
        if jacpaths:
            for p in jacpaths.split(":"):
                p = p.strip()
                if p and p not in search_paths:
                    search_paths.append(p)

        target_comps = spec.target.split(".")
        for search_path in search_paths:
            candidate = os.path.join(search_path, "/".join(target_comps))
            if os.path.isdir(candidate) or os.path.isfile(candidate + ".jac"):
                spec.full_target = os.path.abspath(candidate)
                return

        if not (
            os.path.exists(spec.full_target)
            or os.path.exists(spec.full_target + ".jac")
        ):
            raise ImportError(
                f"Unable to locate module '{spec.target}' in {search_paths}"
            )

    def run_import(
        self, spec: ImportPathSpec, reload: Optional[bool] = False
    ) -> ImportReturn:
        """Run the import process for Jac modules."""
        from jaclang.runtimelib.machine import JacMachine

        unique_loaded_items: list[types.ModuleType] = []
        module = None

        self._resolve_target(spec)
        if os.path.isfile(spec.full_target + ".jac"):
            module_name = self.get_sys_mod_name(spec.full_target + ".jac")
            module_name = spec.override_name if spec.override_name else module_name
        else:
            module_name = self.get_sys_mod_name(spec.full_target)

        module = JacMachine.loaded_modules.get(module_name)

        if not module or module.__name__ == "__main__" or reload:
            if os.path.isdir(spec.full_target):
                module = self.handle_directory(spec.module_name, spec.full_target)
            else:
                spec.full_target += ".jac" if spec.language == "jac" else ".py"
                module = self.create_jac_py_module(
                    module_name,
                    spec.package_path,
                    spec.full_target,
                )
                codeobj = JacMachine.program.get_bytecode(full_target=spec.full_target)

                # Since this is a compile time error, we can safely raise an exception here.
                if not codeobj:
                    raise ImportError(f"No bytecode found for {spec.full_target}")

                try:
                    with sys_path_context(spec.caller_dir):
                        exec(codeobj, module.__dict__)
                except Exception as e:
                    logger.error(e)
                    logger.error(dump_traceback(e))
                    raise e

        import_return = ImportReturn(module, unique_loaded_items, self)
        if spec.items:
            import_return.process_items(
                module=module, items=spec.items, lang=spec.language
            )
        self.result = import_return
        return self.result
