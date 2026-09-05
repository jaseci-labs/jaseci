import os;
import sys;

import from jaclang { JacRuntime as Jac }
import from jaclang.compiler.frontend.constant { Constants as Con }
import type from jaclang.runtime.context { ExecutionContext }
import from jaclang.jac0core.ext_registry { base_stem }
import from jaclang.server.server { JacAPIServer, ServerExtension }
import from jaclang.server.settings { ServeSettings }


obj PreparedInProcessRuntime {
    has server: any,
        transport_kind: str,
        client: any | None = None,
        _prior_ctx: (ExecutionContext | None) = None;

    def close {
        if self.client is not None {
            self.client.close();
            self.client = None;
        }

        Jac.set_shared_root_resolver(None);
        self.server = None;

        if self._prior_ctx is not None {
            Jac.set_context(self._prior_ctx);
        }
        self._prior_ctx = None;
    }
}


def _extensions_for(profile: str) -> list[ServerExtension] {
    if profile == "desktop" {
        return [];
    }
    if profile in ("test", "full") {
        return list(Jac.get_server_extensions());
    }
    raise ValueError(
        "unknown endpoint_profile '"
            + str(profile)
            + "' (expected 'desktop', 'test', or 'full')"
    );
}


def prepare_inprocess_runtime(
    jac_file: str,
    base_path: str,
    endpoint_profile: str = "full",
    setup_background_services: bool = True,
    transport_kind: str = "testclient"
) -> PreparedInProcessRuntime {
    import from jaclang.testing.testkit { ServingTestClient }

    if transport_kind != "testclient" {
        raise NotImplementedError(
            "transport_kind='"
                + str(transport_kind)
                + "' is not implemented; "
                + "only 'testclient' (in-process, single serialized worker) is "
                + "supported today. 'asgi' / 'isolated_worker' are reserved for the "
                + "execution-isolation choice recorded in #6596 P0-0."
        );
    }

    (base, _) = os.path.split(jac_file);
    base = base or "./";
    mod = base_stem(jac_file);
    os.makedirs(base_path, exist_ok=True);
    Jac.set_base_path(base_path);

    prior_ctx = Jac.exec_ctx;
    mach = Jac.create_j_context(user_root=None);
    Jac.set_context(mach);
    try {
        if mod in Jac.loaded_modules {
            del Jac.loaded_modules[mod];
        }
        if mod in sys.modules {
            del sys.modules[mod];
        }
        Jac.jac_import(target=mod, base_path=base, lng="jac");

        server = JacAPIServer(
            module_name=mod,
            port=0,
            base_path=base_path,
            module_file=jac_file,
            settings=ServeSettings.load(base_path, {'no_client': True}),
            extensions=_extensions_for(endpoint_profile)
        );
        server.load_module();
        server._ensure_internal_users();
        server.build_app();
        if setup_background_services {
            server._register_scheduled_tasks();
            server.scheduler.start_if_pending();
            for ext in (server.extensions or []) {
                ext.on_worker_start(server);
            }
        }
        client = ServingTestClient(app=server.app, raise_server_exceptions=False);
        return PreparedInProcessRuntime(
            server=server,
            transport_kind=transport_kind,
            client=client,
            _prior_ctx=prior_ctx
        );
    } except Exception {
        if mod in Jac.loaded_modules {
            del Jac.loaded_modules[mod];
        }
        if mod in sys.modules {
            del sys.modules[mod];
        }
        Jac.set_shared_root_resolver(None);
        if prior_ctx is not None {
            Jac.set_context(prior_ctx);
        }
        mach.close();
        raise;
    }
}
