"""Root layout fixture for the React file-based-routing auth test.

`layouts["/"]` in the generated entry: chrome that wraps every matched route via
`<Outlet/>`. The harness asserts it stays mounted even when the guard redirects,
so "the protected page did not render" is distinguishable from "nothing mounted".
"""

import from "@jac/runtime" { Outlet }

def:pub layout -> JsxLayout {
    <div data-testid="layout">
        <nav data-testid="chrome">chrome</nav>
        <Outlet/>
    </div>
}
