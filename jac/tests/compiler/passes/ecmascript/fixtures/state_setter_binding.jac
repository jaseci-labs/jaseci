"""A client state setter remains a first-class binding."""

obj:pub Box {
    has theme: str = "",
        setTheme: any = None;
}

def:pub use_thing -> Box {
    has theme: str = "dark";
    return Box(theme=theme, setTheme=setTheme);
}

def:pub app -> JsxElement {
    return <div>{use_thing().theme}</div>;
}
