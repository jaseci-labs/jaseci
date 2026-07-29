"""Sample Jac module containing client-side declarations."""

cl glob API_LABEL: str = "Runtime Test";

cl obj ButtonProps {
    has label: str = "Tap Me",
        color: str = "primary";
}

cl def app {
    props = ButtonProps(label="Tap Me", color="primary");
    <div class="app">
        <h1>{API_LABEL}</h1>
        <button class={props.color} data-id="button">{props.label}</button>
    </div>
}
