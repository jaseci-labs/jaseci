"""Shared web component: raw HTML is legal here because only the web app
(client_kind "web") imports it. Under a mobUI app the <div> would be E1105."""

import from core.helper { label }

def:pub Card(count: int) -> JsxElement {
    return <div>{label(count)}</div>;
}
