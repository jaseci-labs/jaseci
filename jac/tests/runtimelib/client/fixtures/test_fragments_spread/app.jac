"""Test fixture for JSX fragments and spread props functionality."""

cl def FragmentTest {
    # Test that fragments work
    <>
        <h1>{"Fragment Title"}</h1>
        <p>{"Fragment content"}</p>
    </>
}

cl def SpreadPropsTest {
    # Test spread props
    unwrapped = {"id": "my-div", "class": "container", "data-role": "main"};

    <div {...unwrapped}>
        <span>{"Spread props work!"}</span>
    </div>
}

cl def MixedTest {
    # Test mixing spread props with regular props
    baseStyle = {"id": "base-id", "color": "blue"};

    <>
        <div {...baseStyle} class="override">{"Mixed test"}</div>
        <div class="normal">{"No spread"}</div>
    </>
}

cl def NestedFragments {
    <div class="wrapper">
        <>
            <h2>{"Nested Fragment 1"}</h2>
        </>
        <>
            <p>{"Nested Fragment 2"}</p>
        </>
    </div>
}

cl def app {
    <div>
        <FragmentTest/>
        <SpreadPropsTest/>
        <MixedTest/>
        <NestedFragments/>
    </div>
}
