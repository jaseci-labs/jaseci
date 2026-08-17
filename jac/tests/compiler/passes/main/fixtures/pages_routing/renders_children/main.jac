"""A `pages/` project whose `app` wrapper renders the route tree.

`children` is declared and rendered, so the generated entry's route tree
reaches the DOM. No E1108."""

def:pub app(children: any = None) -> JsxElement {
    return <div class="shell">{children}</div>;
}
