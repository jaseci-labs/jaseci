"""Both branches of one `if` occupy the same child position."""

def:pub IfElse -> JsxElement {
    has empty: bool = True;

    return
        <div>
            {if empty {
                <p>none</p>
            } else {
                <span>some</span>
            } }
        </div>;
}
