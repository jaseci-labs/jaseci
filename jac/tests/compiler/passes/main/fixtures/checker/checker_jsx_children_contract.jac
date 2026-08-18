"""JSX children are part of the component contract.

The codegen destructures a component's declared parameter names out of `props`
with no rest element, so every child the call site passes to a component that
declares no `children` parameter is discarded -- silently, with a blank render
and no console error. W1053 makes that a diagnostic at the call site.

Zero-parameter components are checked too. They used to skip prop validation
entirely, so an undeclared attribute on one was accepted without a word.

`JsxPage` and `JsxLayout` components are checked too. They are what every
`pages/` route and layout module returns -- the files this contract exists
for -- and the codegen lowers them through the very same props protocol.

A component element with children parses into three `JsxElement` nodes: the
opening tag, the closing tag, and the complete element that owns both. Only
the complete one is a call site. The two tag nodes carry no attributes, so
validating them reports every required prop as missing -- which is why
`Required` below, whose prop has no default, must draw no `E1102`."""

obj TypedProps {
    has title: str;
}

def Titled(title: str = "T") -> JsxElement {
    return <div>{title}</div>;
}

def WithChildren(title: str = "T", children: any = None) -> JsxElement {
    return <div>{title}{children}</div>;
}

def ZeroParam -> JsxElement {
    return <div>zero</div>;
}

def Required(title: str) -> JsxElement {
    return <div>{title}</div>;
}

def TitledPage(title: str = "T") -> JsxPage {
    return <div>{title}</div>;
}

def TypedBag(props: TypedProps) -> JsxElement {
    return <div>{props.title}</div>;
}

glob
     # W1053: `Titled` declares no `children`, so `hello` is dropped.
     a = <Titled title="ok">hello</Titled>,
     # W1053: an element child is dropped just the same.
     b = <Titled title="ok">
         <ZeroParam/>
     </Titled>,
     # OK: `WithChildren` declares `children`.
     c = <WithChildren title="ok">hello</WithChildren>,
     # OK: no children passed at all.
     d = <Titled title="ok"/>,
     # W1053: a zero-parameter component drops children too -- it is compiled
     # as `function ZeroParam()` and never reads its props.
     e = <ZeroParam>hello</ZeroParam>,
     # E1101: zero-parameter components are no longer exempt from prop checks.
     f = <ZeroParam bogus="x"/>,
     # OK: a single `props` parameter is passed through whole, so children
     # arrive in `props.children` rather than being dropped.
     g = <TypedBag title="ok">hello</TypedBag>,
     # OK: whitespace and comments are not children.
     h = <Titled title="ok">
         {#* not a child *#}
     </Titled>,
     # W1053: a route module's `-> JsxPage` component drops children just as
     # an element-returning one does.
     i = <TitledPage title="ok">hello</TitledPage>,
     # W1053, and no E1102: `title` has no default, so the closing tag would
     # report it missing if tag nodes were validated as call sites.
     j = <Required title="ok">hello</Required>;
