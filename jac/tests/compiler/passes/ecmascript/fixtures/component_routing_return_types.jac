"""The routing return annotations are components, as much as `JsxElement` is.

`JsxPage` and `JsxLayout` are what a `pages/` route and layout module return,
and a union is a component if either arm is. `EsastGenPass` lowers all of them
through the props protocol -- the emitted function takes one `props` object and
destructures the declared names out of it -- and `TypeCheckPass` applies the JSX
contract diagnostics (W1052, E1108, E1109) to exactly the same set, because both
read the one predicate they share in `jaclang.compiler.jsx_component`.

Keying either side on `JsxElement` alone is what let `def Card(props: any, tone:
str) -> JsxPage` reach the emitter, where it becomes `const {props, tone} =
props` -- invalid JavaScript, in precisely the `pages/` files the contract
diagnostics exist for.
"""

def:pub PageComp(title: str) -> JsxPage {
    return <div>{title}</div>;
}

def:pub LayoutComp(title: str) -> JsxLayout {
    return <div>{title}</div>;
}

def:pub UnionComp(title: str) -> JsxElement | None {
    return <div>{title}</div>;
}

def:pub ElementComp(title: str) -> JsxElement {
    return <div>{title}</div>;
}
