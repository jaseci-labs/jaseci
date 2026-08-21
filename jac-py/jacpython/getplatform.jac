# Product-path facade for staged ``jac-py/Modules/getplatform.jac`` (wave 1).
# Keep byte-identical to the staged oracle (see ``test_p2_staged_sync.jac``).
def Py_GetPlatform() -> str {
    return "linux";
}
