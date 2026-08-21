import from compiler_slice { compile_parsed_exec, oracle_exec }
import from objects { PyCode }
import from opcode_meta { opcode_name }

glob src = (
         "try:\n"
         + "    raise ValueError('x')\n"
         + "except ValueError:\n"
         + "    raise\n"
     );

with entry {
    actual = compile_parsed_exec(src);
    exp = oracle_exec(src, "<f>") as PyCode;
    ci = 0;
    while ci < len(actual.co_code) {
        op = actual.co_code[ci];
        arg = actual.co_code[ci + 1];
        print(str(ci) + " act " + opcode_name(op) + " " + str(arg));
        ci = ci + 2;
    }
    print("--- exp ---");
    ci = 0;
    while ci < len(exp.co_code) {
        op = exp.co_code[ci];
        arg = exp.co_code[ci + 1];
        print(str(ci) + " exp " + opcode_name(op) + " " + str(arg));
        ci = ci + 2;
    }
}
