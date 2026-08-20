"""Fixture: a client module that names something nothing ever binds.

Nothing in this module declares `missingHelper`, no import brings it in, and
it is not part of the browser's ambient surface. Emitting it as a bare
identifier ships a module that throws ReferenceError the moment the component
renders, with `jac check` green and the build exiting 0 -- so codegen has to
refuse it instead.
"""

def:pub app() -> JsxElement {
    return <div>{missingHelper()}</div>;
}
