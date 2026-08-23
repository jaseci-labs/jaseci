# P3 — ``__slots__`` layout helpers + ``type_ready`` flags (import-free leaf).
# Used by ``typeobject`` / ``ceval`` during ``PyType_Ready`` class finalization.
# Mirrors CPython type_new dict/weakref inheritance rules for heap types.

glob Py_TPFLAGS_READY: int = 4096,
     Py_TPFLAGS_READYING: int = 8192;

# ``PyType_Ready`` flag stub — set READY; slot name finalization is separate.
def type_ready(flags: int) -> int {
    if (flags & Py_TPFLAGS_READY) != 0 {
        return flags;
    }
    if (flags & Py_TPFLAGS_READYING) != 0 {
        return -1;
    }
    return flags | Py_TPFLAGS_READY;
}

def slots_is_dict_name(name: str) -> bool {
    return name == "__dict__";
}

def slots_is_weakref_name(name: str) -> bool {
    return name == "__weakref__";
}

# Drop layout specials; keep member slot names in declaration order (deduped).
def type_slots_filter_members(names: list[str]) -> list[str] {
    members: list[str] = [];
    seen: dict[str, bool] = {};
    for name in names {
        if slots_is_dict_name(name) or slots_is_weakref_name(name) {
            continue;
        }
        if name in seen {
            continue;
        }
        seen[name] = True;
        members.append(name);
    }
    return members;
}

def type_slots_wants_dict(names: list[str]) -> bool {
    for name in names {
        if slots_is_dict_name(name) {
            return True;
        }
    }
    return False;
}

def type_slots_wants_weakref(names: list[str]) -> bool {
    for name in names {
        if slots_is_weakref_name(name) {
            return True;
        }
    }
    return False;
}

# Merge local member slots with inherited member slots (local first, then base).
def type_slots_merge_names(local_names: list[str], inherited: list[str]) -> list[str] {
    merged: list[str] = [];
    seen: dict[str, bool] = {};
    for name in local_names {
        if name in seen {
            continue;
        }
        seen[name] = True;
        merged.append(name);
    }
    for name in inherited {
        if name in seen {
            continue;
        }
        seen[name] = True;
        merged.append(name);
    }
    return merged;
}

# Instance ``__dict__`` presence:
# - no ``__slots__`` declaration → always has a dict
# - with ``__slots__`` → has dict if ``__dict__`` is listed OR any base has a dict
def type_slots_has_dict(
    has_slots_decl: bool, local_wants_dict: bool, base_has_dict: bool
) -> bool {
    if not has_slots_decl {
        return True;
    }
    return local_wants_dict or base_has_dict;
}

# Weakref support (GC-less approximation for layout flags):
# - no ``__slots__`` → allowed
# - with ``__slots__`` → needs ``__weakref__`` in local slots or a base that has it
def type_slots_has_weakrefs(
    has_slots_decl: bool, local_wants_weakref: bool, base_has_weakrefs: bool
) -> bool {
    if not has_slots_decl {
        return True;
    }
    return local_wants_weakref or base_has_weakrefs;
}

# Assignment / deletion gate for instance attributes.
def type_slots_attr_allowed(
    name: str, has_instance_dict: bool, slot_names: list[str]
) -> bool {
    if has_instance_dict {
        return True;
    }
    for s in slot_names {
        if s == name {
            return True;
        }
    }
    return False;
}

def type_slots_dict_visible(has_instance_dict: bool) -> bool {
    return has_instance_dict;
}

# Slot member names belong in fixed storage, not the instance ``__dict__`` view
# (CPython: ``d.a`` with ``__slots__=('a','__dict__')`` stays out of ``d.__dict__``).
def type_slots_in_dict_view(name: str, slot_names: list[str]) -> bool {
    for s in slot_names {
        if s == name {
            return False;
        }
    }
    return True;
}

# Install a member descriptor only when the class body did not already bind the name
# (CPython ``TypeError`` on conflict; callers may soft-skip instead of failing).
def type_slots_should_install_member(namespace_has_name: bool) -> bool {
    return not namespace_has_name;
}

# Repr text for ``member_descriptor`` (matches CPython ``member_getsets``).
def type_slots_member_repr(member_name: str, owner_name: str) -> str {
    return "<member '" + member_name + "' of '" + owner_name + "' objects>";
}
