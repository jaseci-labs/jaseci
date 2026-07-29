cl import from .button { CustomButton }

cl def RelativeImport -> JsxElement {
    <div>
        <CustomButton/>
    </div>
}

cl def app -> JsxElement {
    <RelativeImport/>
}
