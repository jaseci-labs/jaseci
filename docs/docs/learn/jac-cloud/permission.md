# Permission Management: Secure Multi-User Access

## Why Permissions Matter

Jac Cloud's permission system lets you control who can access different parts of your application. This is crucial for:

- Building multi-user applications
- Protecting sensitive data
- Enabling collaboration features
- Creating public/private content
- Implementing access control

## Key Concepts for Beginners

### Understanding Data Representations

In Jac Cloud, your data exists in two forms:

| Type | Database (Anchor) | In-Memory (Archetype) | Description |
|------|-------------------|----------------------|-------------|
| Node | NodeAnchor | NodeArchetype | Represents graph nodes |
| Edge | EdgeAnchor | EdgeArchetype | Connections between nodes |
| Walker | WalkerAnchor | WalkerArchetype | Code that traverses the graph |
| Root | NodeAnchor | Root(NodeArchetype) | Special node representing a user |

### Permission Levels Explained

Jac Cloud has four permission levels that control what users can do:

| Level | Description | Example Use Case |
|-------|-------------|-----------------|
| `NO_ACCESS` | Cannot see or interact with the item | Private user data |
| `READ` | Can view but not modify the item | Public profile information |
| `CONNECT` | Can link nodes to this node | Friend requests, comments |
| `WRITE` | Full access to modify the item | User's own content |

## How Permissions Work (Simple Example)

Imagine a social media app with three users:

```
Root1 → User1 → Post1
Root2 → User2 → Post2
Root3 → User3 → Post3
```

By default, User2 cannot see Post1 (created by User1). To allow this:

1. User1 must explicitly grant permission to User2
2. This creates a connection in the permissions system
3. Now User2 can access Post1 according to the permission level granted

## Managing Permissions in Code

### Option 1: Grant Access Using Helper Functions

```jac
# Allow User2 to read a post
walker grant_access {
    has target_root_id: str;  # ID of User2's root
    has access_level: str;    # "READ", "CONNECT", or "WRITE"

    can grant_access with post entry {
        # Grant access to the current post
        _.allow_root(here, NodeAnchor.ref(self.target_root_id), self.access_level);
        report "Access granted!";
    }
}
```

### Option 2: Revoke Access Using Helper Functions

```jac
# Remove User2's access to a post
walker revoke_access {
    has target_root_id: str;  # ID of User2's root

    can revoke_access with post entry {
        # Revoke access to the current post
        _.disallow_root(here, NodeAnchor.ref(self.target_root_id));
        report "Access revoked!";
    }
}
```

### Option 3: Make Content Public

```jac
# Make a post readable by everyone
walker make_public {
    can make_public with post entry {
        # Grant READ access to all users
        _.perm_grant(here, "READ");
        report "Post is now public!";
    }
}
```

### Option 4: Make Content Private

```jac
# Make a post private (owner-only)
walker make_private {
    can make_private with post entry {
        # Remove all access
        _.perm_revoke(here);
        report "Post is now private!";
    }
}
```

## Common Permission Patterns

### Public Read, Private Write

Perfect for social media posts or articles:

```jac
# Create a public post
walker create_public_post {
    has content: str;

    can enter with `root entry {
        # Create the post
        post = Post({content: self.content});
        here ++> post;

        # Make it readable by everyone, but only writable by owner
        _.perm_grant(post, "READ");

        report "Public post created!";
    }
}
```

### Group Access

Ideal for team collaboration:

```jac
# Grant access to a team
walker grant_team_access {
    has team_members: list[str];  # List of root IDs
    has access_level: str;        # "READ", "CONNECT", or "WRITE"

    can grant_access with document entry {
        # Grant access to each team member
        for member_id in self.team_members {
            _.allow_root(here, NodeAnchor.ref(member_id), self.access_level);
        }

        report "Team access granted!";
    }
}
```

### Connection-based Permissions

For friend systems or social networks:

```jac
# Only friends can see posts
walker check_access {
    has viewer_id: str;

    can check with post entry {
        owner = [post<--][0];

        # Check if viewer is friends with owner
        is_friend = False;
        for friend in [owner -->] {
            if friend.id == self.viewer_id {
                is_friend = True;
                break;
            }
        }

        if is_friend {
            # Grant access if they're friends
            _.allow_root(here, NodeAnchor.ref(self.viewer_id), "READ");
            report "Access granted to friend!";
        } else {
            report "Access denied - not a friend!";
        }
    }
}
```

## Best Practices for Beginners

1. **Start restrictive**: Begin with tight permissions and open up as needed
2. **Use helper functions**: Prefer `_.allow_root()` over direct manipulation
3. **Check permissions**: Use `_.check_read_access()` to verify permissions
4. **Document your scheme**: Keep track of which nodes have which permissions
5. **Batch similar permissions**: Update permissions for multiple nodes at once

## Next Steps

- Learn about [WebSocket Communication](websocket.md) for real-time features
- Explore [Webhook Integration](webhook.md) for third-party service integration
- Set up [Logging & Monitoring](logging.md) to track access patterns