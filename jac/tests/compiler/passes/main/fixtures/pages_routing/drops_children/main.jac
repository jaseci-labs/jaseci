"""A `pages/` project whose `app` wrapper drops the route tree.

The generated entry renders this `app` with the whole route tree as its
children. Declaring no `children` parameter discards them, so the project
renders one stale page and no route ever appears -- E1108."""

def:pub Home -> JsxElement {
    return <div>home</div>;
}

def:pub app -> JsxElement {
    return <Home/>;
}
