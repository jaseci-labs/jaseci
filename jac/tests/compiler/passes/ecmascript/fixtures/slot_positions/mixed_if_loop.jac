"""A conditional followed by a loop in one slot."""

def:pub MixedIfLoop -> JsxElement {
    has show: bool = True,
        tags: list[str] = [];

    return
        <div>
            {if show {
                <p>header</p>
            }for t in tags {
                <li key={t}>{t}</li>
            }}
        </div>;
}
