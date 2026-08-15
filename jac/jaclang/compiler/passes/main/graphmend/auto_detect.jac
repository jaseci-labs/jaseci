import ast as ast3;
import re;
import from jaclang.jac0core.helpers { read_file_with_encoding }

glob _STRIP_RE = re.compile(
         "'''[\\s\\S]*?'''"
             + '|"""[\\s\\S]*?"""'
             + '|"(?:\\\\.|[^"\\\\\\n])*"'
             + "|'(?:\\\\.|[^'\\\\\\n])*'"
             + '|#\\*[\\s\\S]*?\\*#'
             + '|#[^\\n]*'
     ),
     _FROM_RE = re.compile('\\bimport\\s+(?:type\\s+)?from\\s+([.\\w]+)'),
     _PLAIN_RE = re.compile('\\bimport\\s+(?!from\\b)([^;{}]*);'),
     _NAME_RE = re.compile('[A-Za-z_][A-Za-z0-9_]*(?:\\.[A-Za-z_][A-Za-z0-9_]*)*');

def module_imports_torch(src: str, file_path: str) -> bool {
    if 'torch' not in src {
        return False;
    }
    if file_path.endswith('.py') {
        return _py_imports_torch(src);
    }
    return _jac_imports_torch(src);
}

def file_imports_torch(file_path: str) -> bool {
    try {
        return module_imports_torch(read_file_with_encoding(file_path), file_path);
    } except Exception {
        return False;
    }
}

def _is_torch_path(path: str) -> bool {
    return (path == 'torch') or path.startswith('torch.');
}

def _py_imports_torch(src: str) -> bool {
    try {
        tree = ast3.parse(src);
    } except (SyntaxError, ValueError) {
        return False;
    }
    for nd in ast3.walk(tree) {
        if isinstance(nd, ast3.Import) {
            for alias in nd.names {
                if _is_torch_path(alias.name) {
                    return True;
                }
            }
        } elif isinstance(nd, ast3.ImportFrom) {
            if (
                nd.level == 0 and (nd.module is not None) and _is_torch_path(nd.module)
            ) {
                return True;
            }
        }
    }
    return False;
}

def _jac_imports_torch(src: str) -> bool {
    cleaned = _STRIP_RE.sub(' ', src);
    for m in _FROM_RE.finditer(cleaned) {
        path = m.group(1);
        if (not path.startswith('.')) and _is_torch_path(path) {
            return True;
        }
    }
    for pm in _PLAIN_RE.finditer(cleaned) {
        for item in pm.group(1).split(',') {
            entry = item.strip();
            if (not entry) or entry.startswith('.') {
                continue;
            }
            nm = _NAME_RE.match(entry);
            if (nm is not None) and _is_torch_path(nm.group(0)) {
                return True;
            }
        }
    }
    return False;
}
