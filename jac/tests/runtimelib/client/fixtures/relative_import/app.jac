import from .button { CustomButton }

def RelativeImport() -> JsxElement {
    return
        <div>
            <CustomButton/>
        </div>;
}

def app() -> JsxElement {
    return <RelativeImport/>;
}
