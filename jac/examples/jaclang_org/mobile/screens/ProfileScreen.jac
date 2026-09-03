import from "@jac/mobui" { View, Text, Pressable, TextInput, ScrollView }
import from core.social_graph { ProfileBundle }
import from mobile.theme { C, styles }
import from mobile.format { display_name }
import from mobile.icon { Icon }
import from mobile.components.Avatar { Avatar }
import from mobile.components.TweetCard { TweetCard }
import from mobile.components.StatusView { EmptyState }

def:pub ProfileScreen(
    profile: ProfileBundle | None,
    editing: bool,
    bioText: str,
    onBioChange: Callable[[str], None],
    onSaveBio: Callable[[], None],
    onStartEdit: Callable[[], None],
    onCancelEdit: Callable[[], None],
    onLogout: Callable[[], None],
    onLike: Callable[[str], None],
    onComment: Callable[[str, str], None],
    onDelete: Callable[[str], None],
) -> JsxElement {
    username = profile.profile.username if profile else "";
    name = display_name(username);
    bio = profile.profile.bio if profile else "";
    followers = len(profile.followers) if profile else 0;
    following = len(profile.following) if profile else 0;
    my_tweets = profile.tweets if profile else [];
    post_count = len(my_tweets);

    <ScrollView
        style={styles.body}
        contentContainerStyle={styles.scrollBody}
        keyboardShouldPersistTaps="handled"
    >
        <View style={styles.profileHero}/>
        <View style={styles.profileHead}>
            <View style={styles.profileTopRow}>
                <Avatar username={username} size={76}/>
                <View style={styles.rowGap}>
                    {if not editing {
                        <Pressable
                            style={styles.outlineBtn}
                            onPress={lambda { onStartEdit(); }}
                        >
                            <Icon name="edit" size={14} color={C.text}/>
                            <Text style={styles.outlineLabel}>Edit</Text>
                        </Pressable>
                    }}
                    <Pressable
                        style={styles.outlineBtn}
                        onPress={lambda { onLogout(); }}
                    >
                        <Icon name="logout" size={14} color={C.text}/>
                        <Text style={styles.outlineLabel}>Log out</Text>
                    </Pressable>
                </View>
            </View>
            <Text style={styles.profileName}>{name or "Setting up..."}</Text>
            <Text style={styles.profileHandle}>{"@" + name}</Text>
            {if editing {
                <View style={styles.editBox}>
                    <TextInput
                        style={styles.bioInput}
                        value={bioText}
                        placeholder="Write your bio"
                        placeholderTextColor={C.muted}
                        multiline={True}
                        onChangeText={onBioChange}
                    />
                    <View style={styles.rowGap}>
                        <Pressable
                            style={styles.pillBtn}
                            onPress={lambda { onSaveBio(); }}
                        >
                            <Text style={styles.primaryLabel}>Save</Text>
                        </Pressable>
                        <Pressable
                            style={styles.ghostBtn}
                            onPress={lambda { onCancelEdit(); }}
                        >
                            <Text style={styles.ghostLabel}>Cancel</Text>
                        </Pressable>
                    </View>
                </View>
            } else {
                <Text style={styles.profileBio}>{bio or "No bio yet"}</Text>
            } }
            <View style={styles.statsRow}>
                <Text style={styles.stat}>
                    <Text style={styles.statNum}>{str(following)}</Text>
                    {" Following"}
                </Text>
                <Text style={styles.stat}>
                    <Text style={styles.statNum}>{str(followers)}</Text>
                    {" " + ("Follower" if followers == 1 else "Followers")}
                </Text>
                <Text style={styles.stat}>
                    <Text style={styles.statNum}>{str(post_count)}</Text>
                    {" " + ("Post" if post_count == 1 else "Posts")}
                </Text>
            </View>
        </View>
        {if post_count == 0 {
            <EmptyState
                icon="feather"
                title="No posts yet"
                hint="Everything you post shows up here."
            />
        } else {
            for tweet in my_tweets {
                <TweetCard
                    key={jid(tweet)}
                    tweet={tweet}
                    myUsername={username}
                    onLike={onLike}
                    onComment={onComment}
                    onDelete={onDelete}
                />
            }
        } }
    </ScrollView>
}
