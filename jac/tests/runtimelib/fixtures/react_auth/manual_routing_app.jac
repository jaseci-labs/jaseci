"""Manual-routing `AuthGuard` fixture for the React jsdom auth test.

Wires every shape `AuthGuard` is used in outside file-based routing, side by
side, so one fixture covers the whole matrix:

  /wrapped         `<AuthGuard>...</AuthGuard>` as a route `element` (the form
                   `jac-cl-auth` documents) -- the guard must render its own
                   children, not a `<Outlet/>` that resolves to nothing.
  /nested          `<AuthGuard/>` as a pathless PARENT route -- the guard has no
                   children and must fall back to `<Outlet/>` so the matched
                   child route renders.
  /layout-guarded  a layout component that wraps `<Outlet/>` in `<AuthGuard>` --
                   the file-based `(auth)/layout.jac` shape, expressed manually.
  /bare            `<AuthGuard/>` with neither children nor child routes -- must
                   render nothing rather than crash.

`chrome` sits outside `<Routes>` so the harness can tell "the guard rendered
nothing" apart from "the app never mounted".
"""

import from "@jac/runtime" { Router, Routes, Route, AuthGuard, Outlet }

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
    <Router>
        <div data-testid="chrome">chrome</div>
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
