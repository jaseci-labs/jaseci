import from "@jac/mobui" { View, Text, Pressable, ScrollView }
import from core.social_graph { Profile, TrendingTag }
import from core.socialize_mobile.theme { C, styles }
import from core.socialize_mobile.format { display_name }
import from core.socialize_mobile.icon { Icon }
import from core.socialize_mobile.components.Avatar { Avatar }
import from core.socialize_mobile.components.StatusView { EmptyState, LoadingRows }

def:pub ExploreScreen(
    profiles: list[Profile],
    followingIds: list[str],
    myProfileId: str,
    trending: list[TrendingTag],
    loading: bool,
    onFollow: Callable[[str], None],
    onUnfollow: Callable[[str], None],
    onTrendPress: Callable[[str], None],
) -> JsxElement {
    others = [
        u
        for u in profiles
        if jid(u) != myProfileId
    ];

    <ScrollView style={styles.body} contentContainerStyle={styles.scrollBody}>
        <Text style={styles.sectionLabel}>Trending</Text>
        {if len(trending) == 0 {
            <Text style={styles.sectionHint}>
                Hashtags people use in their posts show up here.
            </Text>
        } else {
            <View style={styles.chipRow}>
                {for tag in trending {
                    <Pressable
                        style={styles.chip}
                        key={tag.tag}
                        onPress={lambda { onTrendPress(tag.tag); }}
                    >
                        <Icon name="trending" size={14} color={C.accent}/>
                        <Text style={styles.chipText}>{tag.tag}</Text>
                        <Text style={styles.chipCount}>{str(tag.count)}</Text>
                    </Pressable>
                }}
            </View>
        } }
        <Text style={styles.sectionLabel}>People</Text>
        {if loading and len(others) == 0 {
            <LoadingRows count={4}/>
        } elif len(others) == 0 {
            <EmptyState
                icon="users"
                title="No one to show"
                hint="Ask a friend to sign up and they will appear here."
            />
        } else {
            for u in others {
                <View style={styles.personRow} key={jid(u)}>
                    <Avatar username={u.username} size={44}/>
                    <View style={styles.personBody}>
                        <Text style={styles.name} numberOfLines={1}>
                            {display_name(u.username)}
                        </Text>
                        <Text style={styles.handle} numberOfLines={1}>
                            {"@" + display_name(u.username)}
                        </Text>
                        <Text style={styles.personBio} numberOfLines={2}>
                            {u.bio or "No bio yet"}
                        </Text>
                    </View>
                    {if jid(u) in followingIds {
                        <Pressable
                            style={styles.outlineBtn}
                            onPress={lambda { onUnfollow(jid(u)); }}
                        >
                            <Icon name="check" size={14} color={C.text}/>
                            <Text style={styles.outlineLabel}>Following</Text>
                        </Pressable>
                    } else {
                        <Pressable
                            style={styles.pillBtn}
                            onPress={lambda { onFollow(jid(u)); }}
                        >
                            <Text style={styles.primaryLabel}>Follow</Text>
                        </Pressable>
                    } }
                </View>
            }
        }  }
    </ScrollView>
}
