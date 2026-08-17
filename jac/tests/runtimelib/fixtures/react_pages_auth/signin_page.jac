"""The configured `auth_redirect` target, at a path that is NOT the default.

A guard that drops its configured redirect lands on `/login` instead, which is
not a route here, so nothing renders -- that is the assertion."""

def:pub page -> JsxPage {
    <div data-testid="signin">Sign in</div>
}
