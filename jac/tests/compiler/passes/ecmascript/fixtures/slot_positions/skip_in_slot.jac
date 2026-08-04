"""`skip` must still reach the loop it was written in."""

def:pub SkipInSlot -> JsxElement {
    has tags: list[str] = [];

    return
        <div>
            {for t in tags {
                if t == "x" {
                    skip;
                }
                <li key={t}>{t}</li>
            }}
        </div>;
}
