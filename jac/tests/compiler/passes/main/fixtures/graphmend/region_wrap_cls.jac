"""A call-site wrapped model class whose forward calls a module helper.

`WrapNet` becomes an entry through `torch.compile(WrapNet())`; the compiled
region must include its methods and close over their call edges, so the print
in `cls_helper` is deferred."""
import torch;

def cls_helper(x: any) -> any {
    print("CLS-HELPER", x);
    return x * 2.0;
}

class WrapNet(torch.nn.Module) {
    def forward(self: any, x: any) -> any {
        y = torch.relu(x);
        return cls_helper(y);
    }
}

glob compiled_net = torch.compile(WrapNet());
