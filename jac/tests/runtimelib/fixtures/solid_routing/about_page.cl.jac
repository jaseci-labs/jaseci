"""About page fixture (flat public route) for the Solid routing jsdom test."""


variant client;
def:pub page -> JsxPage {
    return <div data-testid="about"><h1>About</h1></div>;
}
