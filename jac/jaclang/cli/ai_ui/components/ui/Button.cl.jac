"""Button primitive -- shadcn-style, driven by global.css `.btn` classes."""


variant client;
def:pub Button(
    label: str,
    onClick: Callable[[], None],
    variant: str = "primary",
    disabled: bool = False
) -> JsxElement {
    cls = "btn" if variant == "primary" else "btn ghost";
    return <button className={cls} {onClick} {disabled}>{label}</button>;
}
