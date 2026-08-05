glob DYNAMIC_TORCH_ATTRS: set[str] = {
         'item',
         'tolist',
         'sum',
         'max',
         'min',
         'mean',
         'prod',
         'argmax',
         'argmin',
         'nonzero',
         'count_nonzero',
         'all',
         'any',
         'equal',
         'allclose',
         'unique'
     },
     LOGGING_PATTERNS: list[str] = ['logger', 'logging', 'warn', 'critical'],
     SIDE_EFFECT_CALLS: set[str] = {'print'};

def is_dynamic_torch_attr(attr: str) -> bool {
    return attr in DYNAMIC_TORCH_ATTRS;
}

def is_side_effect_name(name: str) -> bool {
    if name in SIDE_EFFECT_CALLS {
        return True;
    }
    lowered = name.lower();
    for pattern in LOGGING_PATTERNS {
        if pattern in lowered {
            return True;
        }
    }
    return False;
}
