"""Sample Jac module using Ant Design components."""

import from antd { Button }

glob APP_NAME: str = "Ant Design Test";

def ButtonTest() {
    return
        <div>
            <h1>{APP_NAME}</h1>
            <p>Testing Ant Design integration</p>
            <Button>Click Me</Button>
        </div>;
}

def CardTest() {
    return
        <div class="card-wrapper">
            <h2>Card Component</h2>
        </div>;
}

def app() {
    return
        <div>
            <ButtonTest/>
            <CardTest/>
        </div>;
}
