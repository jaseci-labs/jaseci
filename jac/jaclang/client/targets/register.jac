import from jaclang.client.targets.registry { get_target_registry }
import from jaclang.client.targets.web_target { WebTarget }
import from jaclang.client.targets.pwa_target { PWATarget }
import from jaclang.client.targets.static_target { StaticTarget }
import from jaclang.client.targets.mobile_target { MobileTarget }
import from jaclang.client.targets.desktop.native_desktop_target { NativeDesktopTarget }
import from jaclang.client.targets.desktop.cef_desktop_target { CefDesktopTarget }
import from jaclang.client.targets.react_native_target { ReactNativeTarget }
import from jaclang.client.targets.bun_target { BunTarget }

def register_targets {
    registry = get_target_registry();
    registry.register(WebTarget());
    registry.register(PWATarget());
    registry.register(StaticTarget());
    registry.register(MobileTarget());
    registry.register(NativeDesktopTarget());

    registry.register(CefDesktopTarget());
    registry.register(ReactNativeTarget());
    registry.register(BunTarget());
}
