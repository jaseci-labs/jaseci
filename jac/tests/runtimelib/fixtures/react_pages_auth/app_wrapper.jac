"""The `main.jac` of a `pages/` project: an `app` that renders the route tree.

The generated entry mounts this with the whole route tree as its children
(`createElement(app, null, createElement(App, null))`). `shell` proves the
wrapper mounted, so "the wrapper dropped the routes" is distinguishable from
"nothing mounted at all"."""

def:pub app(children: any = None) -> JsxElement {
    <div data-testid="shell">{children}</div>
}
