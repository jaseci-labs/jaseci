"""Protected page fixture (`auth: true`) for the React file-based-routing auth test.

Stands in for `pages/(auth)/dashboard.jac`: the generated entry nests it under
the pathless `AuthGuard` route, so it mounts only when the guard sees a
logged-in session.
"""

def:pub page -> JsxPage {
    <div data-testid="dashboard">
        <h1>Dashboard</h1>
    </div>
}
