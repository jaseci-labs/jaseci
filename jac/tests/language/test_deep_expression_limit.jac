"""A long operator chain compiles instead of exhausting the compiler's stack.

The chain is generated rather than committed: at these sizes the fixture
would be tens of kilobytes of source.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { JAC_ROOT }

def write_chain(dir: str, operands: int) -> str {
    path = os.path.join(dir, "chain.jac");
    body = "+".join(["1"] * operands);
    with open(path, "w") as f {
        f.write(f"with entry {{\n    x = {body};\n    print(x);\n}}\n");
    }
    return path;
}

def run_jac(cmd: str, path: str) -> str {
    result = subprocess.run(
        [sys.executable, "-m", "jaclang", cmd, path],
        capture_output=True,
        text=True,
        cwd=JAC_ROOT
    );
    return result.stdout + result.stderr;
}

test "a five thousand operand chain compiles with nothing degraded" {
    with tempfile.TemporaryDirectory() as dir {
        out = run_jac("run", write_chain(dir, 5000));
        assert "5000" in out , out;
        assert "✖ Error" not in out , out;
        assert "maximum recursion depth" not in out , out;
        assert "internal compiler error" not in out , out;
    }
}

test "a ten thousand operand chain still gives the right answer" {
    # Native lowering recurses per operator and gives out near six thousand,
    # so above that the compiler falls back and warns; the answer stays right.
    with tempfile.TemporaryDirectory() as dir {
        out = run_jac("run", write_chain(dir, 10000));
        assert "10000" in out , out;
        assert "✖ Error" not in out , out;
    }
}

test "a ten thousand operand chain type checks" {
    with tempfile.TemporaryDirectory() as dir {
        out = run_jac("check", write_chain(dir, 10000));
        assert "maximum recursion depth" not in out , out;
        assert "1 passed" in out , out;
    }
}
