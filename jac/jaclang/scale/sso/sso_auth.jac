import logging;
import from jaclang.server.identity.user_manager { UserManager }
import from jaclang.server.serving.datatypes { Request, Response }
import from jaclang.server.transport { TransportResponse, Meta }
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.config.firebase_env { firebase_project_id_env_hint }
import from jaclang.scale.shared.enums { Platforms, Operations }
import from jaclang.scale.shared.utils {
    generate_random_password,
    is_safe_loopback_redirect
}
import from jaclang.scale.sso.provider { SSOProvider, SSOUserInfo }

glob logger = logging.getLogger(__name__);


def sso_host -> str {
    return str(get_scale_config().get_sso_config()['host']);
}


def configured_platforms -> dict[str, dict[str, str]] {
    sso_config = get_scale_config().get_sso_config();
    platforms: dict[str, dict[str, str]] = {};
    for platform in Platforms {
        key = platform.value.lower();
        platform_config = sso_config.get(key, {});
        if platform.value == Platforms.FIREBASE.value {
            project_id = platform_config.get('project_id', '');
            if not project_id {
                continue;
            }
            platforms[platform.value] = {"project_id": project_id};
        } else {
            client_id = platform_config.get('client_id', '');
            client_secret = platform_config.get('client_secret', '');
            if not client_id or not client_secret {
                continue;
            }
            platforms[platform.value] = {
                "client_id": client_id,
                "client_secret": client_secret
            };
        }
    }
    return platforms;
}


obj SSOAuth {
    has users: UserManager,
        platforms: dict[str, dict[str, str]] = {};

    def postinit {
        if not self.platforms {
            self.platforms = configured_platforms();
        }
    }

    def get_sso(platform: str) -> SSOProvider | None;
    async def sso_initiate(
        platform: str, operation: str, client_callback: str | None = None
    ) -> Response | TransportResponse;

    async def sso_callback(request: Request, platform: str) -> TransportResponse;
    async def firebase_token_auth_with_id_token(id_token: str) -> TransportResponse;
    def _complete_sso_login(
        platform: str, user_info: SSOUserInfo
    ) -> TransportResponse;
}


impl SSOAuth.get_sso(platform: str) -> SSOProvider | None {
    if platform not in self.platforms {
        return None;
    }
    credentials = self.platforms[platform];
    if platform == Platforms.FIREBASE.value {
        import from jaclang.scale.sso.firebase { FirebaseSSOProvider }
        return FirebaseSSOProvider(project_id=credentials['project_id']);
    } elif platform == Platforms.GOOGLE.value {
        redirect_uri = f"{sso_host()}/sso/{platform}/callback";
        import from jaclang.scale.sso.google { GoogleSSOProvider }
        return GoogleSSOProvider(
            client_id=credentials['client_id'],
            client_secret=credentials['client_secret'],
            redirect_uri=redirect_uri,
            allow_insecure_http=True
        );
    } elif platform == Platforms.APPLE.value {
        redirect_uri = f"{sso_host()}/sso/{platform}/callback";
        import from jaclang.scale.sso.apple { AppleSSOProvider }
        return AppleSSOProvider(
            client_id=credentials['client_id'],
            client_secret=credentials['client_secret'],
            redirect_uri=redirect_uri,
            allow_insecure_http=True
        );
    } elif platform == Platforms.GITHUB.value {
        redirect_uri = f"{sso_host()}/sso/{platform}/callback";
        import from jaclang.scale.sso.github { GithubSSOProvider }
        return GithubSSOProvider(
            client_id=credentials['client_id'],
            client_secret=credentials['client_secret'],
            redirect_uri=redirect_uri,
            allow_insecure_http=True
        );
    }
    return None;
}

impl SSOAuth.sso_initiate(
    platform: str, operation: str, client_callback: str | None = None
) -> Response | TransportResponse {
    if platform not in [p.value for p in Platforms] {
        return TransportResponse.fail(
            code='INVALID_PLATFORM',
            message=f"Invalid platform '{platform}'. Supported platforms: {', '.join(
                [p.value for p in Platforms]
            )}",
            meta=Meta(extra={'http_status': 400})
        );
    }

    if platform == Platforms.FIREBASE.value {
        return TransportResponse.fail(
            code='INVALID_OPERATION',
            message=(
                "Firebase Auth does not use redirect-based SSO flows. "
                "Send the Firebase ID token directly to "
                "POST /sso/firebase/token with a JSON body "
                '{"id_token": "<token>"}.'
            ),
            meta=Meta(extra={'http_status': 400})
        );
    }
    if platform not in self.platforms {
        return TransportResponse.fail(
            code='SSO_NOT_CONFIGURED',
            message=f"SSO for platform '{platform}' is not configured. Please set SSO_{platform.upper()}_CLIENT_ID and SSO_{platform.upper()}_CLIENT_SECRET environment variables.",
            meta=Meta(extra={'http_status': 501})
        );
    }
    if operation not in [o.value for o in Operations] {
        return TransportResponse.fail(
            code='INVALID_OPERATION',
            message=f"Invalid operation '{operation}'. Must be 'login' or 'register'",
            meta=Meta(extra={'http_status': 400})
        );
    }
    sso = self.get_sso(platform);
    if not sso {
        return TransportResponse.fail(
            code='SSO_INIT_FAILED',
            message=f"Failed to initialize SSO for platform '{platform}'",
            meta=Meta(extra={'http_status': 500})
        );
    }

    state = client_callback if is_safe_loopback_redirect(client_callback) else None;
    return await sso.initiate_auth(state=state);
}

impl SSOAuth.sso_callback(request: Request, platform: str) -> TransportResponse {
    if platform not in [p.value for p in Platforms] {
        return TransportResponse.fail(
            code='INVALID_PLATFORM',
            message=f"Invalid platform '{platform}'. Supported platforms: {', '.join(
                [p.value for p in Platforms]
            )}",
            meta=Meta(extra={'http_status': 400})
        );
    }
    if platform not in self.platforms {
        return TransportResponse.fail(
            code='SSO_NOT_CONFIGURED',
            message=f"SSO for platform '{platform}' is not configured.",
            meta=Meta(extra={'http_status': 501})
        );
    }
    sso = self.get_sso(platform);
    if not sso {
        return TransportResponse.fail(
            code='SSO_INIT_FAILED',
            message=f"Failed to initialize SSO for platform '{platform}'",
            meta=Meta(extra={'http_status': 500})
        );
    }
    try {
        user_info = await sso.handle_callback(request);
    } except Exception as e {
        return TransportResponse.fail(
            code='AUTHENTICATION_FAILED',
            message=f"Authentication failed: {str(e)}",
            meta=Meta(extra={'http_status': 401})
        );
    }

    return self._complete_sso_login(platform, user_info);
}

impl SSOAuth.firebase_token_auth_with_id_token(id_token: str) -> TransportResponse {
    platform = Platforms.FIREBASE.value;
    if platform not in self.platforms {
        return TransportResponse.fail(
            code='SSO_NOT_CONFIGURED',
            message=(
                "Firebase Auth SSO is not configured. Set "
                "[scale.sso.firebase] project_id in jac.toml or "
                f"{firebase_project_id_env_hint()}"
            ),
            meta=Meta(extra={'http_status': 501})
        );
    }
    sso: any = self.get_sso(platform);
    if sso is None {
        return TransportResponse.fail(
            code='SSO_INIT_FAILED',
            message=f"Failed to initialize SSO for platform '{platform}'",
            meta=Meta(extra={'http_status': 500})
        );
    }
    try {
        user_info = await sso.handle_id_token(id_token);
    } except Exception as e {
        return TransportResponse.fail(
            code='AUTHENTICATION_FAILED',
            message=f"Firebase authentication failed: {str(e)}",
            meta=Meta(extra={'http_status': 401})
        );
    }

    return self._complete_sso_login(platform, user_info);
}

impl SSOAuth._complete_sso_login(
    platform: str, user_info: SSOUserInfo
) -> TransportResponse {
    email = user_info.email;
    if not email {
        return TransportResponse.fail(
            code='EMAIL_MISSING',
            message=f"Email not provided by {platform}",
            meta=Meta(extra={'http_status': 400})
        );
    }
    external_id = user_info.external_id;
    sso_fields = user_info.profile_fields();

    existing = self.users.find_user_by_identity(email);
    if existing {
        user_id = existing.get('user_id', '');

        self.users.link_sso_account(user_id, platform, external_id);

        if sso_fields {
            raw_profile = existing.get('profile') if existing else None;
            current_profile: dict[str, any] = (
                raw_profile if isinstance(raw_profile, dict) else {}
            );

            raw_sso = current_profile.get('sso');
            current_sso: dict[str, any] = raw_sso if isinstance(raw_sso, dict) else {};
            current_sso[platform] = sso_fields;
            current_profile['sso'] = current_sso;
            self.users.update_user_fields(user_id, {'profile': current_profile});
        }
        token = self.users.create_jwt_token(user_id);
        return TransportResponse.success(
            data={
                'message': 'Login successful',
                'user_id': user_id,
                'token': token,
                'platform': platform,
                'root_id': existing.get('root_id', '')
            },
            meta=Meta(extra={'http_status': 200})
        );
    }

    sso_profile = {'sso': {platform: sso_fields}} if sso_fields else None;
    result = self.users.create_user_with_identities(
        identities=[{'type': 'email', 'value': email, 'verified': True}],
        credential={'type': 'password', 'password': generate_random_password()},
        profile=sso_profile
    );
    if 'error' in result {
        return TransportResponse.fail(
            code='USER_CREATION_FAILED',
            message=result.get('error', 'User creation failed'),
            meta=Meta(extra={'http_status': 400})
        );
    }
    user_id = result.get('user_id', '');

    self.users.link_sso_account(user_id, platform, external_id);
    result['token'] = self.users.create_jwt_token(user_id);
    result['platform'] = platform;
    return TransportResponse.success(
        data=result, meta=Meta(extra={'http_status': 201})
    );
}
