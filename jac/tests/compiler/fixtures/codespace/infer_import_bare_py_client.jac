"""A client component reaches `useRef` through a bare (Python-ecosystem)
import. The PY requirement pins the import server-side, the ES backend
prunes it from the client bundle, and the browser dies with
`ReferenceError: useRef is not defined` -- previously with zero compile
diagnostics. Must be E5084 at compile time; the fix is the quoted npm
form `import from "react" { useRef }`."""

import from react { useRef }

def:pub Widget -> JsxElement {
    holder: any = useRef(None);
    <div>{holder.current}</div>
}
