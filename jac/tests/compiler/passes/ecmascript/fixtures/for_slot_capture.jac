"""Fixture: per-item handlers built inside a `for` slot (#8168).

Three sections build one handler per item, each closing over a local first
assigned in the body that produces the item:

- `for_slot` assigns bare.  Jac scoping is python-like, so the name binds one
  function-level symbol and every handler observes the last iteration's value.
  This section is the footgun the W6009 diagnostic reports; its emitted shape
  is pinned so the intended scoping stays visible.
- `annotated` declares the same value with an explicit type.  A typed
  declaration in a loop body declares a per-iteration local, so each handler
  keeps its own item.  This is the in-source escape hatch #8083 documented.
- `map_lambda` is the control: #8130 made lambda bodies variable-owning, so
  its locals were already per-invocation.
"""

def:pub Handlers(items: any, sink: any) -> JsxElement {
    def fire(text: str) {
        sink(text);
    }

    return
        <div>
            <div id="for_slot">
                {for s in items {
                    slotId = str(s.id);
                    <button onClick={lambda { fire("for_slot:" + slotId); }}>
                        {slotId}
                    </button>;
                }}
            </div>
            <div id="map_lambda">
                {items.map(
                    lambda (m: any) -> any {
                        mapId = str(m.id);
                        return
                            <button onClick={lambda { fire("map_lambda:" + mapId); }}>
                                {mapId}
                            </button>;
                    }
                )}
            </div>
            <div id="annotated">
                {for a in items {
                    annId: str = str(a.id);
                    <button onClick={lambda { fire("annotated:" + annId); }}>
                        {annId}
                    </button>;
                }}
            </div>
        </div>;
}
