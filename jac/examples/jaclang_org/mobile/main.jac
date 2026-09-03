import from "@jac/runtime" {
    jacSignup,
    jacLogin,
    jacLogout,
    jacIsLoggedIn,
    __getLocalStorage,
    __setLocalStorage,
    __removeLocalStorage,
    BridgeError,
    BridgeUnavailable,
    BridgeTimeout,
    BridgeRejected
}
import from "@jac/mobui" { View, Text, StatusBar, ActivityIndicator, useWindowDimensions }
import from core.social_graph {
    setup_profile,
    get_profile,
    get_all_profiles,
    get_trending,
    load_feed,
    get_channels,
    create_tweet,
    create_channel,
    follow_user,
    unfollow_user,
    like_tweet,
    delete_tweet,
    add_comment,
    join_channel,
    leave_channel,
    get_channel_detail,
    create_channel_tweet
}
import from core.social_graph { Profile, Tweet, TrendingTag, ProfileBundle, ChannelBundle }
import from .theme { C, styles }
import from .icon { Icon }
import from .components.TabBar { TabBar }
import from .components.BridgeBanner { BridgeBanner }
import from .screens.AuthScreen { AuthScreen }
import from .screens.FeedScreen { FeedScreen }
import from .screens.ExploreScreen { ExploreScreen }
import from .screens.ChannelsScreen { ChannelsScreen }
import from .screens.ProfileScreen { ProfileScreen }

glob USERNAME_KEY: str = "socialize_username";

glob TAB_TITLES: dict[str, str] = {
    "feed": "Home",
    "explore": "Explore",
    "channels": "Channels",
    "profile": "Profile"
};

def:pub app -> JsxElement {
    has checkingAuth: bool = True,
        isLoggedIn: bool = False,
        isSignup: bool = False,
        authUsername: str = "",
        authPassword: str = "",
        authError: str = "",
        authLoading: bool = False,
        activeTab: str = "feed",
        myProfile: ProfileBundle | None = None,
        tweets: list[Tweet] = [],
        feedLoading: bool = True,
        refreshing: bool = False,
        posting: bool = False,
        composerText: str = "",
        searchQuery: str = "",
        allProfiles: list[Profile] = [],
        peopleLoading: bool = False,
        trendingTags: list[TrendingTag] = [],
        editingBio: bool = False,
        bioText: str = "",
        channels: list[ChannelBundle] = [],
        channelsLoading: bool = False,
        selectedChannel: ChannelBundle | None = None,
        channelPosts: list[Tweet] = [],
        bridgeMessage: str = "",
        bridgeRetry: str = "";

    viewport = useWindowDimensions();

    can with entry {
        isLoggedIn = jacIsLoggedIn();
        checkingAuth = False;
    }

    can with [isLoggedIn] entry {
        if isLoggedIn {
            loadData();
        }
    }

    def reportBridge(e: BridgeError, retry: str) -> None;
    def dismissBridge -> None;
    async def retryBridge -> None;
    async def loadData -> None;
    async def refreshFeed -> None;
    async def refreshProfile -> None;
    async def refreshPeople -> None;
    async def refreshTrending -> None;
    async def refreshChannels -> None;
    async def refreshChannelDetail(channelId: str) -> None;
    async def handleLogin -> None;
    async def handleSignup -> None;
    def handleLogout -> None;
    async def postTweet -> None;
    async def handleRefresh -> None;
    async def handleSearch -> None;
    async def clearSearch -> None;
    async def handleTrendPress(tag: str) -> None;
    async def handleLike(tweetId: str) -> None;
    async def handleComment(tweetId: str, content: str) -> None;
    async def handleDelete(tweetId: str) -> None;
    async def handleFollow(profileId: str) -> None;
    async def handleUnfollow(profileId: str) -> None;
    def startEditBio -> None;
    async def handleSaveBio -> None;
    async def navigate(tab: str) -> None;
    async def handleCreateChannel(name: str, description: str) -> None;
    async def handleJoinChannel(channelId: str) -> None;
    async def handleLeaveChannel(channelId: str) -> None;
    async def handleSelectChannel(channelId: str) -> None;
    async def handleChannelPost(text: str) -> None;
    def handleBackToChannels -> None;

    if checkingAuth {
        return
            <View style={styles.center}>
                <ActivityIndicator size="large" color={C.accent}/>
            </View>;
    }

    if not isLoggedIn {
        return
            <AuthScreen
                isSignup={isSignup}
                username={authUsername}
                password={authPassword}
                error={authError}
                loading={authLoading}
                onUsernameChange={lambda (t: str) { authUsername = t; }}
                onPasswordChange={lambda (t: str) { authPassword = t; }}
                onSubmit={lambda {
                    if isSignup {
                        handleSignup();
                    } else {
                        handleLogin();
                    }
                }}
                onToggleMode={lambda {
                    isSignup = not isSignup;
                    authError = "";
                }}
            />;
    }

    profileUsername = myProfile.profile.username if myProfile else "";
    myProfileId = jid(myProfile.profile) if myProfile else "";
    followingIds = [jid(f) for f in (myProfile.following if myProfile else [])];

    <View style={[styles.root, {"height": viewport.height}]}>
        <StatusBar barStyle="light-content" backgroundColor={C.bg}/>
        <View style={styles.page}>
            <View style={styles.header}>
                <View style={styles.headerBrand}>
                    <View style={styles.headerLogo}>
                        <Icon name="feather" size={16} color={C.accentText}/>
                    </View>
                    <Text style={styles.headerTitle}>{TAB_TITLES[activeTab]}</Text>
                </View>
                <Text style={styles.headerHandle} numberOfLines={1}>
                    {"@" + profileUsername if profileUsername else ""}
                </Text>
            </View>
            {if bridgeMessage {
                <BridgeBanner
                    message={bridgeMessage}
                    canRetry={bridgeRetry != ""}
                    onRetry={retryBridge}
                    onDismiss={dismissBridge}
                />
            }}
            <View style={styles.body}>
                {if activeTab == "feed" {
                    <FeedScreen
                        username={profileUsername}
                        composerText={composerText}
                        onComposerChange={lambda (t: str) { composerText = t; }}
                        onPost={postTweet}
                        posting={posting}
                        searchQuery={searchQuery}
                        onSearchChange={lambda (t: str) { searchQuery = t; }}
                        onSearch={handleSearch}
                        onClearSearch={clearSearch}
                        loading={feedLoading}
                        refreshing={refreshing}
                        onRefresh={handleRefresh}
                        tweets={tweets}
                        onLike={handleLike}
                        onComment={handleComment}
                        onDelete={handleDelete}
                    />
                } elif activeTab == "explore" {
                    <ExploreScreen
                        profiles={allProfiles}
                        followingIds={followingIds}
                        myProfileId={myProfileId}
                        trending={trendingTags}
                        loading={peopleLoading}
                        onFollow={handleFollow}
                        onUnfollow={handleUnfollow}
                        onTrendPress={handleTrendPress}
                    />
                } elif activeTab == "channels" {
                    <ChannelsScreen
                        channels={channels}
                        loading={channelsLoading}
                        selected={selectedChannel}
                        posts={channelPosts}
                        username={profileUsername}
                        onCreate={handleCreateChannel}
                        onJoin={handleJoinChannel}
                        onLeave={handleLeaveChannel}
                        onSelect={handleSelectChannel}
                        onBack={handleBackToChannels}
                        onPost={handleChannelPost}
                        onLike={handleLike}
                        onComment={handleComment}
                        onDelete={handleDelete}
                    />
                } else {
                    <ProfileScreen
                        profile={myProfile}
                        editing={editingBio}
                        bioText={bioText}
                        onBioChange={lambda (t: str) { bioText = t; }}
                        onSaveBio={handleSaveBio}
                        onStartEdit={startEditBio}
                        onCancelEdit={lambda { editingBio = False; }}
                        onLogout={handleLogout}
                        onLike={handleLike}
                        onComment={handleComment}
                        onDelete={handleDelete}
                    />
                }}
            </View>
            <TabBar activeTab={activeTab} onNavigate={navigate}/>
        </View>
    </View>
}
