"""A manual-routing project: no `pages/` directory.

The generated entry renders `app` directly (`createElement(app, null)`), so
the no-argument form is correct here and must not be flagged."""

def:pub AppShell -> JsxElement {
    return <div>shell</div>;
}

def:pub app -> JsxElement {
    return <AppShell/>;
}
