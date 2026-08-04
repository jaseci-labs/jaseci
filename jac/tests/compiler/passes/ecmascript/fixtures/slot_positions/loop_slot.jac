"""A loop is the one genuinely dynamic slot construct."""

def:pub LoopSlot -> JsxElement {
    has tags: list[str] = [];

    return
        <div>
            {for t in tags {
                <li key={t}>{t}</li>
            }}
        </div>;
}
