### Chapter 12: Walkers as API Endpoints

Jac revolutionizes API development by allowing walkers to serve as entry points into your application. Instead of writing separate endpoint handlers, parameter validation, and routing logic, you simply declare walkers as entry points. This chapter explores how to build modern APIs using walkers, transforming graph traversals into web services.

#### 12.1 Entry Point Walkers

### Declaring Walkers as Entry Points

Any walker can become an API endpoint through simple declaration:

```jac
walker GetUserProfile {
    has user_id: str = "";
    has include_stats: bool = false;

    can fetch_profile with entry {
        # If no user_id provided, get current user's profile
        if not self.user_id {
            self.user_id = get_current_user_id();
        }

        # Find profile
        profiles = root[-->:UserProfile:(?.user_id == self.user_id):];
        if not profiles {
            report {
                "success": false,
                "error": "Profile not found"
            };
            return;
        }

        profile = profiles[0];
        response = {
            "success": true,
            "data": {
                "user_id": profile.user_id,
                "display_name": profile.display_name,
                "bio": profile.bio,
                "created_at": profile.created_at
            }
        };

        if self.include_stats {
            response["data"]["stats"] = self.gather_stats(profile);
        }

        report response;
    }

    can gather_stats(profile: UserProfile) -> dict {
        return {
            "posts": len(profile[-->:Post:]),
            "followers": len(profile[<--:Follows:]),
            "following": len(profile[-->:Follows:])
        };
    }
}

node UserProfile {
    has user_id: str;
    has display_name: str;
    has bio: str;
    has created_at: str;
}
```

When deployed, this walker automatically becomes an endpoint:
```bash
# API call
GET /api/GetUserProfile?user_id=alice123&include_stats=true

# Response
{
    "success": true,
    "data": {
        "user_id": "alice123",
        "display_name": "Alice Johnson",
        "bio": "Software engineer and Jac enthusiast",
        "created_at": "2024-01-15T10:30:00Z",
        "stats": {
            "posts": 42,
            "followers": 156,
            "following": 89
        }
    }
}
```

### Parameter Mapping from External Calls

Walker properties automatically map to API parameters:

```jac
walker CreatePost {
    has title: str;
    has content: str;
    has tags: list[str] = [];
    has draft: bool = false;

    # Type validation happens automatically!
    can validate_input() -> tuple {
        if not self.title {
            return (false, "Title is required");
        }

        if len(self.title) > 200 {
            return (false, "Title too long (max 200 chars)");
        }

        if not self.content {
            return (false, "Content is required");
        }

        if len(self.tags) > 10 {
            return (false, "Too many tags (max 10)");
        }

        return (true, "");
    }

    can create with entry {
        # Validate input
        (valid, error) = self.validate_input();
        if not valid {
            report {
                "success": false,
                "error": error
            };
            return;
        }

        # Create post
        posts_container = root[-->:PostsContainer:][0]
            if root[-->:PostsContainer:]
            else root ++> PostsContainer();

        post = posts_container ++> Post(
            id=generate_id(),
            title=self.title,
            content=self.content,
            tags=self.tags,
            draft=self.draft,
            author_id=get_current_user_id(),
            created_at=datetime.now(),
            updated_at=datetime.now()
        );

        # Add tags as nodes
        for tag_name in self.tags {
            tag = get_or_create_tag(tag_name);
            post ++>:HasTag:++> tag;
        }

        report {
            "success": true,
            "data": {
                "id": post.id,
                "title": post.title,
                "created_at": post.created_at,
                "url": f"/posts/{post.id}"
            }
        };
    }
}

node Post {
    has id: str;
    has title: str;
    has content: str;
    has tags: list[str];
    has draft: bool;
    has author_id: str;
    has created_at: str;
    has updated_at: str;
    has view_count: int = 0;
}
```

API usage:
```bash
# POST request
POST /api/CreatePost
Content-Type: application/json

{
    "title": "Getting Started with Jac",
    "content": "Jac is a revolutionary programming language...",
    "tags": ["programming", "jac", "tutorial"],
    "draft": false
}

# Response
{
    "success": true,
    "data": {
        "id": "post_abc123",
        "title": "Getting Started with Jac",
        "created_at": "2024-03-15T14:30:00Z",
        "url": "/posts/post_abc123"
    }
}
```

### Result Mapping

Control exactly what data is returned:

```jac
walker SearchPosts {
    has query: str;
    has tags: list[str] = [];
    has author: str = "";
    has limit: int = 20;
    has offset: int = 0;
    has sort_by: str = "relevance";  # relevance, date, popularity

    has results: list = [];
    has total_count: int = 0;

    can search with entry {
        all_posts = root[-->:PostsContainer:][0][-->:Post:];

        # Filter posts
        filtered = all_posts.filter(lambda p: Post -> bool :
            self.matches_criteria(p)
        );

        self.total_count = len(filtered);

        # Sort
        sorted_posts = self.sort_posts(filtered);

        # Paginate
        paginated = sorted_posts[self.offset:self.offset + self.limit];

        # Transform for response
        for post in paginated {
            self.results.append(self.transform_post(post));
        }

        report {
            "success": true,
            "data": {
                "posts": self.results,
                "pagination": {
                    "total": self.total_count,
                    "limit": self.limit,
                    "offset": self.offset,
                    "has_more": self.offset + self.limit < self.total_count
                }
            }
        };
    }

    can matches_criteria(post: Post) -> bool {
        # Text search
        if self.query {
            text = (post.title + " " + post.content).lower();
            if self.query.lower() not in text {
                return false;
            }
        }

        # Tag filter
        if self.tags {
            post_tags = set(post.tags);
            required_tags = set(self.tags);
            if not required_tags.issubset(post_tags) {
                return false;
            }
        }

        # Author filter
        if self.author and post.author_id != self.author {
            return false;
        }

        # Don't show drafts unless author is searching own posts
        if post.draft and post.author_id != get_current_user_id() {
            return false;
        }

        return true;
    }

    can sort_posts(posts: list[Post]) -> list[Post] {
        if self.sort_by == "date" {
            return posts.sorted(key=lambda p: p.created_at, reverse=true);
        } elif self.sort_by == "popularity" {
            return posts.sorted(key=lambda p: p.view_count, reverse=true);
        } else {  # relevance
            # Simple relevance: posts with query in title rank higher
            return posts.sorted(
                key=lambda p: (
                    self.query.lower() in p.title.lower(),
                    p.view_count
                ),
                reverse=true
            );
        }
    }

    can transform_post(post: Post) -> dict {
        # Get author info
        author = root[-->:UserProfile:(?.user_id == post.author_id):][0];

        return {
            "id": post.id,
            "title": post.title,
            "excerpt": post.content[:200] + "..." if len(post.content) > 200 else post.content,
            "tags": post.tags,
            "author": {
                "id": author.user_id,
                "display_name": author.display_name
            },
            "created_at": post.created_at,
            "view_count": post.view_count
        };
    }
}
```

#### 12.2 Building Services

### RESTful Patterns with Walkers

Implement complete REST APIs using walker patterns:

```jac
# Base CRUD walker pattern
walker ResourceManager {
    has resource_type: str;
    has resource_id: str = "";
    has method: str;  # GET, POST, PUT, DELETE
    has data: dict = {};

    can route with entry {
        match self.method {
            case "GET":
                if self.resource_id {
                    self.get_one();
                } else {
                    self.get_many();
                }
            case "POST": self.create();
            case "PUT": self.update();
            case "DELETE": self.delete();
            case _: self.method_not_allowed();
        }
    }

    can get_one abs;
    can get_many abs;
    can create abs;
    can update abs;
    can delete abs;

    can method_not_allowed {
        report {
            "success": false,
            "error": f"Method {self.method} not allowed"
        };
    }
}

# Concrete implementation for Posts
walker PostAPI(ResourceManager) {
    can get_one {
        posts = root[-->*:Post:(?.id == self.resource_id):];
        if not posts {
            report {"success": false, "error": "Post not found"};
            return;
        }

        post = posts[0];
        post.view_count += 1;  # Increment views

        report {
            "success": true,
            "data": self.serialize_post(post, detailed=true)
        };
    }

    can get_many {
        container = root[-->:PostsContainer:][0];
        posts = container[-->:Post:].filter(
            lambda p: Post -> bool : not p.draft or p.author_id == get_current_user_id()
        );

        report {
            "success": true,
            "data": {
                "posts": [self.serialize_post(p) for p in posts],
                "count": len(posts)
            }
        };
    }

    can create {
        container = root[-->:PostsContainer:][0]
            if root[-->:PostsContainer:]
            else root ++> PostsContainer();

        post = container ++> Post(
            id=generate_id(),
            title=self.data.get("title", ""),
            content=self.data.get("content", ""),
            tags=self.data.get("tags", []),
            draft=self.data.get("draft", false),
            author_id=get_current_user_id(),
            created_at=datetime.now(),
            updated_at=datetime.now()
        );

        report {
            "success": true,
            "data": self.serialize_post(post),
            "location": f"/api/posts/{post.id}"
        };
    }

    can update {
        posts = root[-->*:Post:(?.id == self.resource_id):];
        if not posts {
            report {"success": false, "error": "Post not found"};
            return;
        }

        post = posts[0];

        # Check ownership
        if post.author_id != get_current_user_id() {
            report {"success": false, "error": "Forbidden"};
            return;
        }

        # Update fields
        if "title" in self.data { post.title = self.data["title"]; }
        if "content" in self.data { post.content = self.data["content"]; }
        if "tags" in self.data { post.tags = self.data["tags"]; }
        if "draft" in self.data { post.draft = self.data["draft"]; }

        post.updated_at = datetime.now();

        report {
            "success": true,
            "data": self.serialize_post(post)
        };
    }

    can delete {
        posts = root[-->*:Post:(?.id == self.resource_id):];
        if not posts {
            report {"success": false, "error": "Post not found"};
            return;
        }

        post = posts[0];

        # Check ownership
        if post.author_id != get_current_user_id() {
            report {"success": false, "error": "Forbidden"};
            return;
        }

        # Delete post and all its edges
        for edge in post[<-->] {
            del edge;
        }
        del post;

        report {
            "success": true,
            "message": "Post deleted successfully"
        };
    }

    can serialize_post(post: Post, detailed: bool = false) -> dict {
        data = {
            "id": post.id,
            "title": post.title,
            "tags": post.tags,
            "author_id": post.author_id,
            "created_at": post.created_at,
            "updated_at": post.updated_at,
            "view_count": post.view_count
        };

        if detailed {
            data["content"] = post.content;
            data["draft"] = post.draft;
        } else {
            data["excerpt"] = post.content[:200] + "..."
                if len(post.content) > 200 else post.content;
        }

        return data;
    }
}

# Usage examples:
# GET /api/posts -> PostAPI(method="GET")
# GET /api/posts/123 -> PostAPI(method="GET", resource_id="123")
# POST /api/posts -> PostAPI(method="POST", data={...})
# PUT /api/posts/123 -> PostAPI(method="PUT", resource_id="123", data={...})
# DELETE /api/posts/123 -> PostAPI(method="DELETE", resource_id="123")
```

### Event Handlers as Walkers

Walkers can handle real-time events:

```jac
walker WebSocketHandler {
    has event_type: str;
    has payload: dict = {};
    has connection_id: str;

    can handle with entry {
        match self.event_type {
            case "subscribe": self.handle_subscribe();
            case "unsubscribe": self.handle_unsubscribe();
            case "message": self.handle_message();
            case "typing": self.handle_typing();
            case _: self.handle_unknown();
        }
    }

    can handle_subscribe {
        channel = self.payload.get("channel", "");
        if not channel {
            self.send_error("Channel required");
            return;
        }

        # Get or create subscription node
        subs = root[-->:Subscriptions:][0]
            if root[-->:Subscriptions:]
            else root ++> Subscriptions();

        # Add subscription
        sub = subs ++> Subscription(
            connection_id=self.connection_id,
            channel=channel,
            subscribed_at=datetime.now()
        );

        self.send_response({
            "event": "subscribed",
            "channel": channel
        });

        # Send recent messages
        self.send_recent_messages(channel);
    }

    can handle_message {
        channel = self.payload.get("channel", "");
        text = self.payload.get("text", "");

        if not channel or not text {
            self.send_error("Channel and text required");
            return;
        }

        # Create message
        msg = Message(
            id=generate_id(),
            channel=channel,
            author_id=get_current_user_id(),
            text=text,
            created_at=datetime.now()
        );

        # Store in channel
        channel_node = get_or_create_channel(channel);
        channel_node ++> msg;

        # Broadcast to subscribers
        self.broadcast_to_channel(channel, {
            "event": "message",
            "data": {
                "id": msg.id,
                "author_id": msg.author_id,
                "text": msg.text,
                "created_at": msg.created_at
            }
        });
    }

    can broadcast_to_channel(channel: str, message: dict) {
        # Find all subscriptions to this channel
        all_subs = root[-->:Subscriptions:][0][-->:Subscription:];
        channel_subs = all_subs.filter(
            lambda s: Subscription -> bool : s.channel == channel
        );

        # Send to each subscriber
        for sub in channel_subs {
            self.send_to_connection(sub.connection_id, message);
        }
    }

    can send_response(data: dict) {
        report {
            "connection_id": self.connection_id,
            "data": data
        };
    }

    can send_error(error: str) {
        self.send_response({
            "event": "error",
            "error": error
        });
    }
}
```

### Long-Running Services

Build services that maintain state across requests:

```jac
# Background job processor
walker JobProcessor {
    has job_id: str = "";
    has action: str = "process";  # submit, status, cancel
    has job_type: str = "";
    has job_data: dict = {};

    can route with entry {
        match self.action {
            case "submit": self.submit_job();
            case "status": self.check_status();
            case "cancel": self.cancel_job();
            case "process": self.process_next_job();
        }
    }

    can submit_job {
        # Get or create job queue
        queue = root[-->:JobQueue:][0]
            if root[-->:JobQueue:]
            else root ++> JobQueue();

        # Create job
        job = queue ++> Job(
            id=generate_id(),
            type=self.job_type,
            data=self.job_data,
            status="pending",
            submitted_by=get_current_user_id(),
            submitted_at=datetime.now()
        );

        report {
            "success": true,
            "job_id": job.id,
            "status": "pending"
        };

        # Trigger processing (in real system, this would be async)
        spawn JobProcessor(action="process") on root;
    }

    can process_next_job {
        queue = root[-->:JobQueue:][0];
        if not queue { return; }

        # Find next pending job
        pending = queue[-->:Job:(?.status == "pending"):];
        if not pending { return; }

        job = pending[0];

        # Mark as processing
        job.status = "processing";
        job.started_at = datetime.now();

        try {
            # Process based on job type
            result = match job.type {
                case "image_resize": self.process_image_resize(job);
                case "report_generation": self.process_report(job);
                case "data_export": self.process_export(job);
                case _: {"error": "Unknown job type"};
            };

            # Mark complete
            job.status = "completed";
            job.completed_at = datetime.now();
            job.result = result;

        } except Exception as e {
            job.status = "failed";
            job.error = str(e);
            job.failed_at = datetime.now();
        }
    }

    can process_image_resize(job: Job) -> dict {
        # Simulate image processing
        import:py time;
        time.sleep(2);

        return {
            "original_size": job.data.get("size", [1920, 1080]),
            "resized_to": job.data.get("target_size", [800, 600]),
            "url": f"/images/resized/{job.id}.jpg"
        };
    }

    can check_status {
        jobs = root[-->*:Job:(?.id == self.job_id):];
        if not jobs {
            report {"success": false, "error": "Job not found"};
            return;
        }

        job = jobs[0];

        report {
            "success": true,
            "job": {
                "id": job.id,
                "type": job.type,
                "status": job.status,
                "submitted_at": job.submitted_at,
                "started_at": job.started_at,
                "completed_at": job.completed_at,
                "result": job.result if job.status == "completed" else None,
                "error": job.error if job.status == "failed" else None
            }
        };
    }
}

node Job {
    has id: str;
    has type: str;
    has data: dict;
    has status: str;
    has submitted_by: str;
    has submitted_at: str;
    has started_at: str? = None;
    has completed_at: str? = None;
    has failed_at: str? = None;
    has result: dict? = None;
    has error: str? = None;
}
```

### API Versioning

Handle multiple API versions elegantly:

```jac
walker APIRouter {
    has version: str = "v1";
    has endpoint: str;
    has method: str = "GET";
    has params: dict = {};

    can route with entry {
        match self.version {
            case "v1": self.route_v1();
            case "v2": self.route_v2();
            case _: self.version_not_found();
        }
    }

    can route_v1 {
        match self.endpoint {
            case "users": spawn UserAPIv1(method=self.method, params=self.params) on root;
            case "posts": spawn PostAPIv1(method=self.method, params=self.params) on root;
            case _: self.endpoint_not_found();
        }
    }

    can route_v2 {
        match self.endpoint {
            case "users": spawn UserAPIv2(method=self.method, params=self.params) on root;
            case "posts": spawn PostAPIv2(method=self.method, params=self.params) on root;
            case "comments": spawn CommentAPI(method=self.method, params=self.params) on root;
            case _: self.endpoint_not_found();
        }
    }

    can version_not_found {
        report {
            "success": false,
            "error": f"API version {self.version} not found",
            "available_versions": ["v1", "v2"]
        };
    }
}

# Version-specific implementations
walker UserAPIv1 {
    has method: str;
    has params: dict;

    can handle with entry {
        # V1 implementation - basic user info
        user = get_current_user_profile();
        report {
            "name": user.display_name,
            "created": user.created_at
        };
    }
}

walker UserAPIv2(UserAPIv1) {
    can handle with entry {
        # V2 adds more fields
        user = get_current_user_profile();
        report {
            "id": user.user_id,
            "name": user.display_name,
            "bio": user.bio,
            "created": user.created_at,
            "stats": {
                "posts": count_user_posts(user),
                "followers": count_followers(user)
            }
        };
    }
}
```

### Authentication and Middleware

Implement authentication as walker patterns:

```jac
walker AuthMiddleware {
    has token: str = "";
    has required_role: str = "";
    has next_walker: type? = None;
    has next_params: dict = {};

    can authenticate with entry {
        # Verify token
        if not self.token {
            report {
                "success": false,
                "error": "Authentication required",
                "code": 401
            };
            return;
        }

        # Validate token and get user
        session = self.validate_token(self.token);
        if not session {
            report {
                "success": false,
                "error": "Invalid token",
                "code": 401
            };
            return;
        }

        # Check role if required
        if self.required_role {
            if not self.has_role(session.user_id, self.required_role) {
                report {
                    "success": false,
                    "error": "Insufficient permissions",
                    "code": 403
                };
                return;
            }
        }

        # Set user context and continue
        set_current_user(session.user_id);

        # Spawn next walker
        if self.next_walker {
            spawn self.next_walker(**self.next_params) on root;
        }
    }

    can validate_token(token: str) -> Session? {
        # Find active session
        sessions = root[-->*:Session:(?.token == token and ?.active):];

        if sessions {
            session = sessions[0];

            # Check expiration
            import:py from datetime import datetime;
            if datetime.fromisoformat(session.expires_at) > datetime.datetime.now() {
                return session;
            }
        }

        return None;
    }

    can has_role(user_id: str, role: str) -> bool {
        profiles = root[-->:UserProfile:(?.user_id == user_id):];
        if profiles {
            return role in profiles[0].roles;
        }
        return false;
    }
}

# Usage: Wrap endpoints with auth
walker AdminEndpoint {
    has token: str;
    has action: str;

    can handle with entry {
        # First, authenticate with admin role
        spawn AuthMiddleware(
            token=self.token,
            required_role="admin",
            next_walker=AdminAction,
            next_params={"action": self.action}
        ) on root;
    }
}

walker AdminAction {
    has action: str;

    can execute with entry {
        # This only runs if authentication passed
        match self.action {
            case "list_users": self.list_all_users();
            case "system_stats": self.get_system_stats();
            case _: report {"error": "Unknown action"};
        }
    }
}
```

### Rate Limiting

Implement rate limiting at the walker level:

```jac
walker RateLimiter {
    has user_id: str = "";
    has endpoint: str;
    has limit: int = 100;  # requests per hour
    has window: int = 3600;  # seconds

    can check_limit with entry {
        if not self.user_id {
            self.user_id = get_current_user_id();
        }

        # Get or create rate limit node
        limits = root[-->:RateLimits:][0]
            if root[-->:RateLimits:]
            else root ++> RateLimits();

        key = f"{self.user_id}:{self.endpoint}";
        tracker = limits[-->:RequestTracker:(?.key == key):];

        if not tracker {
            # Create new tracker
            tracker = [limits ++> RequestTracker(
                key=key,
                requests=[]
            )];
        }

        tracker_node = tracker[0];

        # Clean old requests
        import:py from datetime import datetime, timedelta;
        cutoff = (datetime.now() - timedelta(seconds=self.window)).isoformat();
        tracker_node.requests = [r for r in tracker_node.requests if r > cutoff];

        # Check limit
        if len(tracker_node.requests) >= self.limit {
            report {
                "success": false,
                "error": "Rate limit exceeded",
                "code": 429,
                "retry_after": self.get_retry_after(tracker_node.requests[0])
            };
            return;
        }

        # Add current request
        tracker_node.requests.append(datetime.now());

        # Continue to actual endpoint
        report {
            "success": true,
            "remaining": self.limit - len(tracker_node.requests),
            "reset": self.get_reset_time()
        };
    }

    can get_retry_after(oldest_request: str) -> int {
        import:py from datetime import datetime;
        oldest = datetime.fromisoformat(oldest_request);
        retry = oldest + timedelta(seconds=self.window) - datetime.now();
        return int(retry.total_seconds());
    }

    can get_reset_time() -> str {
        import:py from datetime import datetime, timedelta;
        return (datetime.now() + timedelta(seconds=self.window)).isoformat();
    }
}

node RequestTracker {
    has key: str;
    has requests: list[str];  # timestamps
}
```

### Error Handling and Responses

Standardize error handling across APIs:

```jac
walker APIBase {
    has include_stack_trace: bool = false;  # Only in dev

    can handle_error(e: Exception, code: int = 500) {
        response = {
            "success": false,
            "error": {
                "message": str(e),
                "code": code,
                "type": type(e).__name__
            }
        };

        if self.include_stack_trace {
            import:py traceback;
            response["error"]["stack_trace"] = traceback.format_exc();
        }

        report response;
    }

    can validate_required(data: dict, fields: list[str]) -> tuple {
        missing = [f for f in fields if f not in data or not data[f]];

        if missing {
            return (false, f"Missing required fields: {', '.join(missing)}");
        }

        return (true, "");
    }

    can success_response(data: any = None, message: str = "") -> dict {
        response = {"success": true};

        if data is not None {
            response["data"] = data;
        }

        if message {
            response["message"] = message;
        }

        return response;
    }

    can paginated_response(
        items: list,
        total: int,
        page: int = 1,
        per_page: int = 20
    ) -> dict {
        return {
            "success": true,
            "data": items,
            "pagination": {
                "total": total,
                "page": page,
                "per_page": per_page,
                "pages": (total + per_page - 1) # per_page,
                "has_prev": page > 1,
                "has_next": page * per_page < total
            }
        };
    }
}

# Use base class for consistent responses
walker UserSearchAPI(APIBase) {
    has query: str = "";
    has page: int = 1;
    has per_page: int = 20;

    can search with entry {
        try {
            if not self.query {
                report self.handle_error(
                    ValueError("Query parameter required"),
                    400
                );
                return;
            }

            # Search users
            all_users = root[-->:UserProfile:];
            matches = all_users.filter(
                lambda u: UserProfile -> bool :
                    self.query.lower() in u.display_name.lower() or
                    self.query.lower() in u.bio.lower()
            );

            # Paginate
            total = len(matches);
            start = (self.page - 1) * self.per_page;
            items = matches[start:start + self.per_page];

            report self.paginated_response(
                items=[self.serialize_user(u) for u in items],
                total=total,
                page=self.page,
                per_page=self.per_page
            );

        } except Exception as e {
            report self.handle_error(e);
        }
    }

    can serialize_user(user: UserProfile) -> dict {
        return {
            "id": user.user_id,
            "display_name": user.display_name,
            "bio": user.bio[:100] + "..." if len(user.bio) > 100 else user.bio
        };
    }
}
```

### Best Practices for Walker APIs

##### 1. **Design Resource-Oriented Endpoints**

```jac
# Good: Resource-focused
walker GetUserPosts {
    has user_id: str;
    has status: str = "published";  # published, draft, all
}

# Bad: Action-focused
walker FetchPostsForUser {
    has user_id: str;
    has include_drafts: bool;
}
```

##### 2. **Use Clear Naming Conventions**

```jac
# Good: Clear, RESTful naming
walker UserAPI {
    has method: str;  # GET, POST, PUT, DELETE
}

walker CreateUser {
    has email: str;
    has password: str;
}

# Bad: Unclear or inconsistent
walker DoUserStuff {
    has action: str;
}
```

##### 3. **Implement Proper Validation**

```jac
walker UpdateProfile {
    has bio: str = "";
    has display_name: str = "";
    has avatar_url: str = "";

    can validate() -> tuple {
        if self.bio and len(self.bio) > 500 {
            return (false, "Bio too long (max 500 chars)");
        }

        if self.display_name and len(self.display_name) < 3 {
            return (false, "Display name too short (min 3 chars)");
        }

        if self.avatar_url and not self.is_valid_url(self.avatar_url) {
            return (false, "Invalid avatar URL");
        }

        return (true, "");
    }
}
```

##### 4. **Handle Errors Gracefully**

```jac
walker SafeAPI {
    can execute with entry {
        try {
            # Main logic
            self.process();
        } except ValidationError as e {
            report {"success": false, "error": str(e), "code": 400};
        } except PermissionError as e {
            report {"success": false, "error": str(e), "code": 403};
        } except NotFoundException as e {
            report {"success": false, "error": str(e), "code": 404};
        } except Exception as e {
            # Log unexpected errors
            log_error(e);
            report {"success": false, "error": "Internal server error", "code": 500};
        }
    }
}
```

##### 5. **Version Your APIs**

```jac
# Include version in walker name or property
walker UserAPIv1 {
    # V1 implementation
}

walker UserAPIv2 {
    # V2 with breaking changes
}

# Or use versioning router
walker APIGateway {
    has version: str = "v1";
    has endpoint: str;

    can route with entry {
        walker_name = f"{self.endpoint}API{self.version}";
        # Dynamic routing based on version
    }
}
```

### Summary

In this chapter, we've explored how walkers naturally become API endpoints:

- **Automatic Parameter Mapping**: Walker properties map directly to API parameters
- **Built-in Validation**: Type checking happens automatically
- **RESTful Patterns**: Easy to implement standard REST APIs
- **Event Handling**: Support for WebSockets and real-time events
- **Service Patterns**: Long-running jobs, queues, and background processing
- **Production Features**: Authentication, rate limiting, versioning

This approach eliminates the traditional separation between business logic and API layer. Your graph traversals ARE your APIs. The same walker that processes data locally can serve web requests globally, making Jac applications truly scale-agnostic.

Next, we'll explore how these APIs can seamlessly distribute across multiple machines, enabling your applications to scale from a single server to a global deployment without changing your code.