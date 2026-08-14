"""Fixture: closures built inside a loop body over a loop-body local (#8168).

Jac scoping is python-like, so a bare assignment in a loop body binds one
symbol in the enclosing function: every closure built in that body reads
whatever the final iteration wrote, silently. Only the `bare` sections have
that shape; every other section already has a per-iteration binding and must
stay silent, or the diagnostic would fire on the fixes it recommends.
"""

def:pub Handlers(items: any, sink: any) -> JsxElement {
    def fire(text: str) {
        sink(text);
    }

    def handler_for(item_id: str) -> any {
        return lambda { fire(item_id); };
    }

    can with entry {
        ticks: any = [];

        # Reported: the `for`-to counter is hoisted out of the loop head, so
        # every closure appended here reads the counter's final value.
        for i = 0 while i < 3 with i += 1 {
            ticks.append(lambda { fire(str(i)); });
        }
    }

    return
        <div>
            <div id="bare">
                {for s in items {
                    bareId = str(s.id);
                    <button onClick={lambda { fire(bareId); }}>{bareId}</button>;
                }}
            </div>
            <div id="annotated">
                {for a in items {
                    annId: str = str(a.id);
                    <button onClick={lambda { fire(annId); }}>{annId}</button>;
                }}
            </div>
            <div id="target">
                {for t in items {
                    <button onClick={lambda { fire(str(t.id)); }}>{str(t.id)}</button>;
                }}
            </div>
            <div id="factory">
                {for f in items {
                    facId = str(f.id);
                    <button onClick={handler_for(facId)}>{facId}</button>;
                }}
            </div>
            <div id="mapped">
                {items.map(
                    lambda (m: any) -> any {
                        mapId = str(m.id);
                        return
                            <button onClick={lambda { fire(mapId); }}>{mapId}</button>;
                    }
                )}
            </div>
        </div>;
}
