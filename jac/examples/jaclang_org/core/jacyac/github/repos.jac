import json;
import from urllib.parse { quote }
import from core.github { fetch }
import from .auth { github_id }

obj GithubRepo {
    has full: str,
        url: str,
        description: str = "",
        stars: int = 0;
}

obj GithubRepos {
    has linked: bool = False,
        login: str = "",
        repos: list[GithubRepo] = [],
        next_page: int = 0,
        error: str = "";
}

def public_api(path: str) -> any {
    data = fetch("https://api.github.com" + path, "JacYac", accept_json=True);
    if data is None {
        raise RuntimeError("GitHub is unavailable or rate limited.");
    }
    return json.loads(data);
}

def:pub github_repositories(session_token: str, page: int = 1) -> GithubRepos {
    external_id = github_id(session_token);
    if not external_id {
        return GithubRepos();
    }
    try {
        info = public_api("/user/" + external_id);
        login = str(info.get("login") or "");
        if str(info.get("id")) != external_id or not login {
            return GithubRepos(
                linked=True, error="Could not verify your GitHub account."
            );
        }
        current = max(1, min(page, 100));
        raw = public_api(
            "/users/"
                + quote(login, safe="")
                + "/repos?type=owner&sort=updated&per_page=30&page="
                + str(current)
        );
        repos: list[GithubRepo] = [];
        for repo in raw {
            if not repo.get("private", True)
                and str(repo.get("owner", {}).get("id")) == external_id {
                full = str(repo["full_name"]);
                repos.append(
                    GithubRepo(
                        full=full,
                        url="https://github.com/" + full,
                        description=str(repo.get("description") or ""),
                        stars=int(repo.get("stargazers_count") or 0)
                    )
                );
            }
        }
        return GithubRepos(
            linked=True,
            login=login,
            repos=repos,
            next_page=current + 1 if len(raw) == 30 else 0
        );
    } except Exception {
        return GithubRepos(
            linked=True, error="Could not load GitHub repositories. Please try again."
        );
    }
}

def verified_owner(full: str, session_token: str) -> bool {
    external_id = github_id(session_token);
    if not external_id {
        return False;
    }
    try {
        repo = public_api("/repos/" + full);
        return not repo.get("private", True)
            and str(repo.get("owner", {}).get("id")) == external_id;
    } except Exception {
        return False;
    }
}
