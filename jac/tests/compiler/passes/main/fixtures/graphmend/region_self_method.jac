"""A scoped-mode model where reachability flows through a self call.

Under scoped compilation `forward` is a seed; `step` joins the region only
through the `self.step(...)` call edge, while `unused` is reachable from
nothing and must stay untouched even though it holds a deferrable print."""
import torch;

class Net(torch.nn.Module) {
    def forward(self: any, x: any) -> any {
        y = torch.relu(x);
        return self.step(y);
    }

    def step(self: any, x: any) -> any {
        print("STEP-EFFECT", x);
        return x * 2.0;
    }

    def unused(self: any, x: any) -> any {
        print("UNUSED-EFFECT", x);
        return x;
    }
}
