import unittest;
import sys;

obj MyRes(unittest.TextTestResult, unittest.TestResult) {
    has stream: any,
        descriptions: any,
        verbosity: int;
}

with entry {
    sys.stdout.write(str(sys.version) + "\n");
    sys.stdout.write(str(MyRes.__mro__) + "\n");
}
