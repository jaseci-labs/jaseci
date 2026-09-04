import os;
import sys;

import from jaclang { JacRuntime as Jac }
import from jaclang.compiler.frontend.constant { Constants as Con }
import type from jaclang.runtime.context { ExecutionContext }
import from jaclang.jac0core.ext_registry { base_stem }
import from jaclang.scale.identity.user_manager { JacScaleUserManager }
import from jaclang.scale.server.serve { JacAPIServer }
import from jaclang.server.identity_owner { CORE_IDENTITY, identity_setting }


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


def _register_endpoint_profile(server: any, profile: str) {
    if profile == "desktop" {
        server.register_health_endpoint();
        server.register_auth_endpoints();
        server.register_walkers_endpoints();
        server.register_functions_endpoints();
    } elif profile == "test" {
        import from jaclang.server.serving.openapi { register_docs_endpoints }
        server.register_health_endpoint();
        server.register_auth_endpoints();
        server.register_graph_endpoint();
        server.register_admin_endpoints();
        server.register_llm_telemetry_endpoints();
        server.register_workloads_endpoints();
        server.register_walkers_endpoints();
        server.register_functions_endpoints();
        server.register_webhook_endpoints();
        server.register_static_file_endpoint();
        server.register_page_endpoint();
        server.register_client_js_endpoint();
        server._configure_openapi_security();
        register_docs_endpoints(server.server.app);
    } elif profile == "full" {
        server._register_endpoints();
    } else {
        raise ValueError(
            "unknown endpoint_profile '"
                + str(profile)
                + "' (expected 'desktop', 'test', or 'full')"
        );
    }
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

    if identity_setting(jac_file) == CORE_IDENTITY {
        raise RuntimeError(
            "the in-process runtime serves the scale identity, and "
                + str(jac_file)
                + " belongs to a project that asks for the core one. Refusing "
                + "to build it anyway: the two stacks keep credentials in "
                + "different databases, so the accounts it served would not be "
                + "the accounts the project has. Drop [serve] identity = "
                + "'core' to let this project serve the scale stack in process."
        );
    }

    (base, _) = os.path.split(jac_file);
    base = base or "./";
    mod = base_stem(jac_file);
    os.makedirs(base_path, exist_ok=True);
    Jac.set_base_path(base_path);

    prior_ctx = Jac.exec_ctx;
    import from jaclang.scale.memory.context { JScaleExecutionContext }
    mach = JScaleExecutionContext();
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
            module_name=mod, port=0, base_path=base_path, module_file=jac_file
        );
        server.load_module();

        _register_endpoint_profile(server, endpoint_profile);

        _um = server.user_manager;
        assert isinstance(_um, JacScaleUserManager) , "the scale server builds a JacScaleUserManager";
        if _um.get_root_id(Con.GUEST.value) is None {
            _um.create_internal_user(Con.GUEST.value, "__no_password__");
        }
        def _shared_root_id -> (str | None) {
            return _um.get_root_id(Con.GUEST.value);
        }
        Jac.set_shared_root_resolver(_shared_root_id);

        if setup_background_services {
            server.setup_emailer();
            server._setup_scheduler();
            server._setup_events();
        }

        native_server = server.server;
        if native_server is None {
            raise RuntimeError("in-process runtime requires a started server");
        }
        client = ServingTestClient(
            app=native_server.app, raise_server_exceptions=False
        );
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
