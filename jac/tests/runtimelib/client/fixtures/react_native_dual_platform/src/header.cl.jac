"""Web variant of the platform header (uses className + CSS)."""


variant client;
def:pub PlatformHeader(props: dict) -> JsxElement {
    return
        <div className="platform-header">
            <h1 className="platform-title">{props.title}</h1>
            <span className="platform-badge">web</span>
        </div>;
}
