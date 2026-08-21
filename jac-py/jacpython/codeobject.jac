# P3.2d — code flag / argcount helpers.
# Lift: Objects/_lifted/codeobject_core.jac

glob CO_OPTIMIZED: int = 1,
     CO_NEWLOCALS: int = 2,
     CO_VARARGS: int = 4,
     CO_VARKEYWORDS: int = 8,
     CO_NESTED: int = 16,
     CO_GENERATOR: int = 32,
     CO_COROUTINE: int = 128,
     CO_ASYNC_GENERATOR: int = 512;

def code_is_generator(flags: int) -> bool {
    return (flags & CO_GENERATOR) != 0;
}

def code_is_coroutine(flags: int) -> bool {
    return (flags & CO_COROUTINE) != 0;
}

def code_has_varargs(flags: int) -> bool {
    return (flags & CO_VARARGS) != 0;
}

def code_has_varkeywords(flags: int) -> bool {
    return (flags & CO_VARKEYWORDS) != 0;
}

def code_total_argcount(argcount: int, kwonlyargcount: int) -> int {
    return argcount + kwonlyargcount;
}
