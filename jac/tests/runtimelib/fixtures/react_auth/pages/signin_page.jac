"""Login page fixture served at the CONFIGURED `[client.routing] auth_redirect`.

Deliberately mounted at `/signin`, not `/login`: the guard is built with
`auth_redirect = "/signin"`, so this page rendering is the proof the configured
value actually reached `AuthGuard` instead of being dropped for the default.
"""

def:pub page -> JsxPage {
    <div data-testid="signin">
        <h1>Sign in</h1>
    </div>
}
