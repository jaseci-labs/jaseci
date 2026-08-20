import unittest;

obj MyRes(unittest.TextTestResult, unittest.TestResult) {
    has stream: any,
        descriptions: any,
        verbosity: int;
}

def probe(x: MyRes) -> int {
    x.shouldStop = True;
    if x.wasSuccessful() {
        return 0;
    }
    return len(x.failures);
}

def probe2(runner: unittest.TextTestRunner, s: unittest.TestSuite) -> int {
    result = runner.run(s);
    assert isinstance(result, MyRes);
    if result.wasSuccessful() {
        return 0;
    }
    return len(result.failures);
}
