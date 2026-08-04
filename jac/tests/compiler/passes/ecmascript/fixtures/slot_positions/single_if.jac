"""One conditional in a slot: a single, non-repeating child."""

def:pub SingleIf -> JsxElement {
    has flag: bool = True;

    return
        <div>
            {if flag {
                <p>hi</p>
            }}
        </div>;
}
