"""The props bundle is all-or-nothing.

A component whose single parameter is named `props` receives the whole
call-site object. Combined with any other parameter there is no coherent
lowering, and the codegen produces one of two broken outputs:

    def Mixed(props: any, tone: str)      -> const {props, tone} = props;
                                             SyntaxError, the bundle never parses
    def MixedKw(props: any, *, tone: str) -> function Mixed(props, tone = "flat")
                                             React passes one object, so `tone`
                                             is always its default and every
                                             `tone=` at a call site is discarded

Both used to pass `jac check`. E1109 rejects the shape at the declaration."""

def Bag(props: any) -> JsxElement {
    return <div>{props.children}</div>;
}

def Named(title: str, tone: str = "flat") -> JsxElement {
    return <div>{title}{tone}</div>;
}

def Mixed(props: any, tone: str = "flat") -> JsxElement {
    return <div>{props.children}{tone}</div>;
}

def MixedKw(props: any, *, tone: str = "flat") -> JsxElement {
    return <div>{props.children}{tone}</div>;
}

def NotAComponent(props: any, tone: str = "flat") -> str {
    return f"{props}{tone}";
}
