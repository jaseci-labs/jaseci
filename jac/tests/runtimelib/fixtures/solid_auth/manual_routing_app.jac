"""Manual-routing `AuthGuard` fixture for the Solid jsdom auth test.

The Solid mirror of `fixtures/react_auth/manual_routing_app.jac`, covering the
shapes the generated `pages/` entry never exercises -- that entry passes
`props.children` into the guard explicitly, which is why no test caught an
`element=` parent route dropping them.

  /wrapped         `<AuthGuard>...</AuthGuard>` as a route `element` -- the
                   children are baked into the element, so they must render.
  /nested          `<AuthGuard/>` as a pathless PARENT route -- the matched
                   child arrives from the router, not from the call site.
  /layout-guarded  a layout wrapping `<Outlet/>` in the guard -- the
                   `(auth)/layout.jac` shape, written manually.
  /bare            neither children nor child routes -- renders nothing, no
                   crash.

`chrome` renders from the router's `root` shell, outside every route, so "the
guard rendered nothing" is distinguishable from "the app never mounted".
"""

import from "@jac/runtime" { Router, Routes, Route, AuthGuard, Outlet }

def:pub Shell(props: any) -> JsxElement {
    <div>
        <div data-testid="chrome">chrome</div>
        {props.children}
    </div>
}

def:pub LoginPage -> JsxElement {
    <div data-testid="login">Login</div>
}

def:pub Dashboard -> JsxElement {
    <div data-testid="dashboard">Dashboard</div>
}

def:pub NestedPage -> JsxElement {
    <div data-testid="nested">Nested</div>
}

def:pub AuthShell -> JsxElement {
    <AuthGuard redirect="/login">
        <Outlet/>
    </AuthGuard>
}

def:pub app -> JsxElement {
    <Router root={Shell}>
        <Routes>
            <Route path="/login" element={<LoginPage/>}/>
            <Route
                path="/wrapped"
                element={<AuthGuard redirect="/login">
                    <Dashboard/>
                </AuthGuard>}
            />
            <Route element={<AuthGuard redirect="/login"/>}>
                <Route path="/nested" element={<NestedPage/>}/>
            </Route>
            <Route element={<AuthShell/>}>
                <Route path="/layout-guarded" element={<Dashboard/>}/>
            </Route>
            <Route path="/bare" element={<AuthGuard redirect="/login"/>}/>
        </Routes>
    </Router>
}
