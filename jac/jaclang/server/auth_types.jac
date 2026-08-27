import from jaclang.comptime { fields }

enum IdentityType { USERNAME = 'username' }


enum CredentialType { PASSWORD = 'password' }


obj IdentityInput {
    has type: str,
        value: str;

    static def from_dict(data: any) -> IdentityInput {
        if not isinstance(data, dict) {
            raise ValueError('identity must be an object');
        }
        kw: dict[str, str] = {};
        comptime for f in fields(IdentityInput) {
            v = data.get(f.name);
            if not isinstance(v, str) or not v {
                raise ValueError(f"identity.{f.name} is required");
            }
            kw[f.name] = v;
        }
        return IdentityInput(**kw);
    }
}


obj CredentialInput {
    has type: str,
        password: str;

    static def from_dict(data: any) -> CredentialInput {
        if not isinstance(data, dict) {
            raise ValueError('credential must be an object');
        }
        kw: dict[str, str] = {};
        comptime for f in fields(CredentialInput) {
            v = data.get(f.name);
            if not isinstance(v, str) or not v {
                raise ValueError(f"credential.{f.name} is required");
            }
            kw[f.name] = v;
        }
        return CredentialInput(**kw);
    }
}


obj LoginRequest {
    has identity: IdentityInput,
        credential: CredentialInput;

    static def from_dict(data: any) -> LoginRequest {
        if not isinstance(data, dict) {
            raise ValueError('request body must be an object');
        }
        if 'identity' not in data {
            raise ValueError('identity is required');
        }
        if 'credential' not in data {
            raise ValueError('credential is required');
        }
        return LoginRequest(
            identity=IdentityInput.from_dict(data.get('identity')),
            credential=CredentialInput.from_dict(data.get('credential'))
        );
    }
}


obj RegisterRequest {
    has identities: list[IdentityInput],
        credential: CredentialInput;

    static def from_dict(data: any) -> RegisterRequest {
        if not isinstance(data, dict) {
            raise ValueError('request body must be an object');
        }
        raw_identities = data.get('identities');
        if not isinstance(raw_identities, list) or len(raw_identities) == 0 {
            raise ValueError('identities must be a non-empty list');
        }
        if 'credential' not in data {
            raise ValueError('credential is required');
        }
        identities = [IdentityInput.from_dict(item) for item in raw_identities];
        return RegisterRequest(
            identities=identities,
            credential=CredentialInput.from_dict(data.get('credential'))
        );
    }
}
