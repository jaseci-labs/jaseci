impl app.reportBridge(e: BridgeError, retry: str) -> None {
    if isinstance(e, BridgeUnavailable) {
        bridgeMessage = "Can't reach the server. Check your connection and try again.";
    } elif isinstance(e, BridgeTimeout) {
        bridgeMessage = "The server is taking too long to answer.";
    } elif isinstance(e, BridgeRejected) {
        bridgeMessage = "The server refused that request. If you signed out elsewhere, log in again.";
    } else {
        bridgeMessage = "Something went wrong talking to the server.";
    }
    bridgeRetry = retry;
}

impl app.dismissBridge -> None {
    bridgeMessage = "";
    bridgeRetry = "";
}

impl app.retryBridge -> None {
    target = bridgeRetry;
    dismissBridge();
    if target == "load" {
        await loadData();
    } elif target == "feed" {
        await refreshFeed();
    } elif target == "people" {
        await refreshPeople();
        await refreshTrending();
    } elif target == "channels" {
        await refreshChannels();
    } elif target == "profile" {
        await refreshProfile();
    }
}

impl app.loadData -> None {
    feedLoading = True;
    try {
        result = root spawn setup_profile(username=__getLocalStorage(USERNAME_KEY) or "");
        myProfile = result.reports[0] if result.reports else None;
        feedResult = root spawn load_feed(search_query="");
        tweets = feedResult.reports[0] if feedResult.reports else [];
        trendResult = root spawn get_trending();
        trendingTags = trendResult.reports[0] if trendResult.reports else [];
        dismissBridge();
    } except BridgeError as e {
        reportBridge(e, "load");
    }
    feedLoading = False;
}

impl app.refreshFeed -> None {
    try {
        feedResult = root spawn load_feed(search_query=searchQuery);
        tweets = feedResult.reports[0] if feedResult.reports else [];
    } except BridgeError as e {
        reportBridge(e, "feed");
    }
}

impl app.refreshProfile -> None {
    try {
        profileResult = root spawn get_profile();
        myProfile = profileResult.reports[0] if profileResult.reports else myProfile;
    } except BridgeError as e {
        reportBridge(e, "profile");
    }
}

impl app.refreshPeople -> None {
    peopleLoading = True;
    try {
        profilesResult = root spawn get_all_profiles();
        allProfiles = profilesResult.reports[0] if profilesResult.reports else [];
    } except BridgeError as e {
        reportBridge(e, "people");
    }
    peopleLoading = False;
}

impl app.refreshTrending -> None {
    try {
        trendResult = root spawn get_trending();
        trendingTags = trendResult.reports[0] if trendResult.reports else [];
    } except BridgeError as e {
        reportBridge(e, "people");
    }
}

impl app.refreshChannels -> None {
    channelsLoading = True;
    try {
        result = root spawn get_channels();
        channels = result.reports[0] if result.reports else [];
    } except BridgeError as e {
        reportBridge(e, "channels");
    }
    channelsLoading = False;
}

impl app.refreshChannelDetail(channelId: str) -> None {
    try {
        detailResult = root spawn get_channel_detail(channel_id=channelId);
        detail = detailResult.reports[0] if detailResult.reports else None;
        if detail {
            selectedChannel = detail;
            channelPosts = detail.posts;
        }
    } except BridgeError as e {
        reportBridge(e, "channels");
    }
}

impl app.handleLogin -> None {
    authError = "";
    if not authUsername.strip() or not authPassword {
        authError = "Please fill in all fields";
        return;
    }
    authLoading = True;
    try {
        ok: bool = await jacLogin(authUsername, authPassword);
        if ok {
            __setLocalStorage(USERNAME_KEY, authUsername);
            authPassword = "";
            isLoggedIn = True;
        } else {
            authError = "Invalid username or password";
        }
    } except BridgeError as e {
        reportBridge(e, "");
        authError = bridgeMessage;
        dismissBridge();
    } except Exception {
        authError = "Could not reach the server. Check your connection and try again.";
    }
    authLoading = False;
}

impl app.handleSignup -> None {
    authError = "";
    if not authUsername.strip() or not authPassword {
        authError = "Please fill in all fields";
        return;
    }
    if len(authPassword) < 4 {
        authError = "Password must be at least 4 characters";
        return;
    }
    authLoading = True;
    try {
        result: dict[str, any] = await jacSignup(authUsername, authPassword);
        if result["success"] {
            ok: bool = await jacLogin(authUsername, authPassword);
            if ok {
                __setLocalStorage(USERNAME_KEY, authUsername);
                authPassword = "";
                isLoggedIn = True;
            } else {
                isSignup = False;
                authError = "Account created. Please log in.";
            }
        } else {
            authError = str(result["error"] if result["error"] else "Signup failed");
        }
    } except BridgeError as e {
        reportBridge(e, "");
        authError = bridgeMessage;
        dismissBridge();
    } except Exception {
        authError = "Could not reach the server. Check your connection and try again.";
    }
    authLoading = False;
}

impl app.handleLogout -> None {
    jacLogout();
    __removeLocalStorage(USERNAME_KEY);
    isLoggedIn = False;
    myProfile = None;
    tweets = [];
    allProfiles = [];
    trendingTags = [];
    channels = [];
    selectedChannel = None;
    channelPosts = [];
    activeTab = "feed";
    authUsername = "";
    authPassword = "";
    authError = "";
    searchQuery = "";
    composerText = "";
    editingBio = False;
    dismissBridge();
}

impl app.postTweet -> None {
    text = composerText.strip();
    if not text or posting {
        return;
    }
    posting = True;
    try {
        root spawn create_tweet(content=text);
        composerText = "";
        await refreshFeed();
        await refreshProfile();
        await refreshTrending();
    } except BridgeError as e {
        reportBridge(e, "");
    }
    posting = False;
}

impl app.handleRefresh -> None {
    refreshing = True;
    await refreshFeed();
    await refreshTrending();
    refreshing = False;
}

impl app.handleSearch -> None {
    await refreshFeed();
}

impl app.clearSearch -> None {
    searchQuery = "";
    await refreshFeed();
}

impl app.handleTrendPress(tag: str) -> None {
    searchQuery = tag;
    activeTab = "feed";
    await refreshFeed();
}

impl app.handleLike(tweetId: str) -> None {
    try {
        root spawn like_tweet(tweet_id=tweetId);
    } except BridgeError as e {
        reportBridge(e, "");
        return;
    }
    await refreshFeed();
    if myProfile {
        await refreshProfile();
    }
    if selectedChannel {
        await refreshChannelDetail(jid(selectedChannel.channel));
    }
}

impl app.handleComment(tweetId: str, content: str) -> None {
    if not content.strip() {
        return;
    }
    try {
        root spawn add_comment(tweet_id=tweetId, content=content.strip());
    } except BridgeError as e {
        reportBridge(e, "");
        return;
    }
    await refreshFeed();
    if myProfile {
        await refreshProfile();
    }
    if selectedChannel {
        await refreshChannelDetail(jid(selectedChannel.channel));
    }
}

impl app.handleDelete(tweetId: str) -> None {
    try {
        root spawn delete_tweet(tweet_id=tweetId);
    } except BridgeError as e {
        reportBridge(e, "");
        return;
    }
    await refreshFeed();
    await refreshProfile();
    if selectedChannel {
        await refreshChannelDetail(jid(selectedChannel.channel));
    }
}

impl app.handleFollow(profileId: str) -> None {
    try {
        root spawn follow_user(target_id=profileId);
    } except BridgeError as e {
        reportBridge(e, "");
        return;
    }
    await refreshProfile();
    await refreshFeed();
}

impl app.handleUnfollow(profileId: str) -> None {
    try {
        root spawn unfollow_user(target_id=profileId);
    } except BridgeError as e {
        reportBridge(e, "");
        return;
    }
    await refreshProfile();
    await refreshFeed();
}

impl app.startEditBio -> None {
    bioText = myProfile.profile.bio if myProfile else "";
    editingBio = True;
}

impl app.handleSaveBio -> None {
    uname = myProfile.profile.username if myProfile else "";
    try {
        root spawn setup_profile(username=uname, bio=bioText.strip());
    } except BridgeError as e {
        reportBridge(e, "");
        return;
    }
    await refreshProfile();
    editingBio = False;
}

impl app.navigate(tab: str) -> None {
    activeTab = tab;
    if tab == "explore" {
        await refreshPeople();
        await refreshTrending();
    } elif tab == "channels" and selectedChannel is None {
        await refreshChannels();
    } elif tab == "profile" {
        await refreshProfile();
    }
}

impl app.handleCreateChannel(name: str, description: str) -> None {
    if not name.strip() {
        return;
    }
    try {
        root spawn create_channel(name=name.strip(), description=description.strip());
    } except BridgeError as e {
        reportBridge(e, "");
        return;
    }
    await refreshChannels();
}

impl app.handleJoinChannel(channelId: str) -> None {
    try {
        root spawn join_channel(channel_id=channelId);
    } except BridgeError as e {
        reportBridge(e, "");
        return;
    }
    await refreshChannels();
    if selectedChannel and jid(selectedChannel.channel) == channelId {
        await refreshChannelDetail(channelId);
    }
}

impl app.handleLeaveChannel(channelId: str) -> None {
    try {
        root spawn leave_channel(channel_id=channelId);
    } except BridgeError as e {
        reportBridge(e, "");
        return;
    }
    await refreshChannels();
    if selectedChannel and jid(selectedChannel.channel) == channelId {
        await refreshChannelDetail(channelId);
    }
}

impl app.handleSelectChannel(channelId: str) -> None {
    await refreshChannelDetail(channelId);
}

impl app.handleChannelPost(text: str) -> None {
    if not text.strip() or selectedChannel is None {
        return;
    }
    channelId = jid(selectedChannel.channel);
    try {
        root spawn create_channel_tweet(channel_id=channelId, content=text.strip());
    } except BridgeError as e {
        reportBridge(e, "");
        return;
    }
    await refreshChannelDetail(channelId);
}

impl app.handleBackToChannels -> None {
    selectedChannel = None;
    channelPosts = [];
}
