import from "@jac/mobui" { View, Pressable, TextInput, ScrollView, RefreshControl }
import from core.social_graph { Tweet }
import from core.socialize_mobile.theme { C, styles }
import from core.socialize_mobile.icon { Icon }
import from core.socialize_mobile.components.Composer { Composer }
import from core.socialize_mobile.components.TweetCard { TweetCard }
import from core.socialize_mobile.components.StatusView { EmptyState, LoadingRows }

def:pub FeedScreen(
    username: str,
    composerText: str,
    onComposerChange: Callable[[str], None],
    onPost: Callable[[], None],
    posting: bool,
    searchQuery: str,
    onSearchChange: Callable[[str], None],
    onSearch: Callable[[], None],
    onClearSearch: Callable[[], None],
    loading: bool,
    refreshing: bool,
    onRefresh: Callable[[], None],
    tweets: list[Tweet],
    onLike: Callable[[str], None],
    onComment: Callable[[str, str], None],
    onDelete: Callable[[str], None],
) -> JsxElement {
    <ScrollView
        style={styles.body}
        contentContainerStyle={styles.scrollBody}
        keyboardShouldPersistTaps="handled"
        refreshControl={<RefreshControl
            refreshing={refreshing}
            onRefresh={lambda { onRefresh(); }}
            tintColor={C.accent}
            colors={[C.accent]}
        />}
    >
        <View style={styles.searchBar}>
            <Icon name="search" size={17} color={C.muted}/>
            <TextInput
                style={styles.searchInput}
                value={searchQuery}
                placeholder="Search posts"
                placeholderTextColor={C.muted}
                autoCapitalize="none"
                returnKeyType="search"
                onChangeText={onSearchChange}
                onSubmitEditing={lambda { onSearch(); }}
            />
            {if searchQuery {
                <Pressable onPress={lambda { onClearSearch(); }}>
                    <Icon name="close" size={16} color={C.muted}/>
                </Pressable>
            }}
        </View>
        <Composer
            username={username}
            placeholder="What's happening?"
            value={composerText}
            onChange={onComposerChange}
            onPost={onPost}
            busy={posting}
        />
        {if loading {
            <LoadingRows count={4}/>
        } elif len(tweets) == 0 {
            <EmptyState
                icon="inbox"
                title={"No matches" if searchQuery else "Nothing here yet"}
                hint={"Try another word or clear the search."
                    if searchQuery
                    else "Follow people or post something to fill your feed."}
            />
        } else {
            for tweet in tweets {
                <TweetCard
                    key={jid(tweet)}
                    tweet={tweet}
                    myUsername={username}
                    onLike={onLike}
                    onComment={onComment}
                    onDelete={onDelete}
                />
            }
        }  }
    </ScrollView>
}
