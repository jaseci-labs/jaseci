import os;

glob CORE_IDENTITY: str = 'core',
     SCALE_IDENTITY: str = 'scale',
     AUTO_IDENTITY: str = 'auto',
     IDENTITY_BACKEND_ENV: str = 'JAC_IDENTITY_BACKEND',
     KNOWN_IDENTITY_OWNERS: tuple[str, str] = (CORE_IDENTITY, SCALE_IDENTITY),
     __all__ = [
         'AUTO_IDENTITY',
         'CORE_IDENTITY',
         'IDENTITY_BACKEND_ENV',
         'KNOWN_IDENTITY_OWNERS',
         'SCALE_IDENTITY',
         'identity_owner',
         'scale_stack_installed',
         'scale_stack_unavailable'
     ];

def scale_stack_installed -> bool;
def identity_owner(project_dir: (str | None) = None) -> str;
def scale_stack_unavailable(module_name: str, error: any = None) -> RuntimeError;
