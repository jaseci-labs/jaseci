import from "@jac/mobui" { View, Text, Pressable, TextInput, ScrollView, Modal }
import from core.social_graph { ChannelBundle, Tweet }
import from mobile.theme { C, styles }
import from mobile.format { count_label }
import from mobile.icon { Icon }
import from mobile.components.Composer { Composer }
import from mobile.components.TweetCard { TweetCard }
import from mobile.components.StatusView { EmptyState, LoadingRows }

def ChannelDetail(
    channel: ChannelBundle,
    posts: list[Tweet],
    username: str,
    onBack: Callable[[], None],
    onJoin: Callable[[str], None],
    onLeave: Callable[[str], None],
    onPost: Callable[[str], None],
    onLike: Callable[[str], None],
    onComment: Callable[[str, str], None],
    onDelete: Callable[[str], None],
) -> JsxElement {
    has draft: str = "";

    channel_id = jid(channel.channel);

    <ScrollView
        style={styles.body}
        contentContainerStyle={styles.scrollBody}
        keyboardShouldPersistTaps="handled"
    >
        <View style={styles.detailHead}>
            <Pressable style={styles.backBtn} onPress={lambda { onBack(); }}>
                <Icon name="back" size={16} color={C.muted}/>
                <Text style={styles.backLabel}>Channels</Text>
            </Pressable>
            <View style={styles.channelRowInner}>
                <View style={styles.channelIcon}>
                    <Icon name="hash" size={20} color={C.accent}/>
                </View>
                <View style={styles.channelBody}>
                    <Text style={styles.channelName} numberOfLines={1}>
                        {channel.channel.name}
                    </Text>
                    <View style={styles.channelMeta}>
                        <Icon name="users" size={12} color={C.muted}/>
                        <Text style={styles.channelMetaText}>
                            {count_label(channel.member_count, "member", "members")}
                        </Text>
                    </View>
                </View>
                {if channel.is_member {
                    <Pressable
                        style={styles.outlineBtn}
                        onPress={lambda { onLeave(channel_id); }}
                    >
                        <Text style={styles.outlineLabel}>Leave</Text>
                    </Pressable>
                } else {
                    <Pressable
                        style={styles.pillBtn}
                        onPress={lambda { onJoin(channel_id); }}
                    >
                        <Text style={styles.primaryLabel}>Join</Text>
                    </Pressable>
                } }
            </View>
            {if channel.channel.description {
                <Text style={styles.channelDesc}>{channel.channel.description}</Text>
            }}
        </View>
        {if channel.is_member {
            <Composer
                username={username}
                placeholder={"Post in #" + channel.channel.name}
                value={draft}
                onChange={lambda (t: str) { draft = t; }}
                onPost={lambda {
                    onPost(draft);
                    draft = "";
                }}
            />
        }}
        {if len(posts) == 0 {
            <EmptyState
                icon="hash"
                title="No posts yet"
                hint={"Be the first to post here."
                    if channel.is_member
                    else "Join this channel to post."}
            />
        } else {
            for tweet in posts {
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

def:pub ChannelsScreen(
    channels: list[ChannelBundle],
    loading: bool,
    selected: ChannelBundle | None,
    posts: list[Tweet],
    username: str,
    onCreate: Callable[[str, str], None],
    onJoin: Callable[[str], None],
    onLeave: Callable[[str], None],
    onSelect: Callable[[str], None],
    onBack: Callable[[], None],
    onPost: Callable[[str], None],
    onLike: Callable[[str], None],
    onComment: Callable[[str, str], None],
    onDelete: Callable[[str], None],
) -> JsxElement {
    has showCreate: bool = False,
        newName: str = "",
        newDescription: str = "";

    def submitCreate -> None {
        name = newName.strip();
        if not name {
            return;
        }
        onCreate(name, newDescription.strip());
        newName = "";
        newDescription = "";
        showCreate = False;
    }

    if selected is not None {
        return
            <ChannelDetail
                channel={selected}
                posts={posts}
                username={username}
                onBack={onBack}
                onJoin={onJoin}
                onLeave={onLeave}
                onPost={onPost}
                onLike={onLike}
                onComment={onComment}
                onDelete={onDelete}
            />;
    }

    <View style={styles.body}>
        <Modal
            visible={showCreate}
            transparent={True}
            animationType="slide"
            onRequestClose={lambda { showCreate = False; }}
        >
            <View style={styles.modalOverlay}>
                <View style={styles.modalCard}>
                    <Text style={styles.modalTitle}>Create a channel</Text>
                    <Text style={styles.modalSub}>
                        Start a space for people to gather around a topic.
                    </Text>
                    <TextInput
                        style={styles.modalInput}
                        value={newName}
                        placeholder="Name, e.g. jac-builders"
                        placeholderTextColor={C.muted}
                        autoCapitalize="none"
                        onChangeText={lambda (t: str) { newName = t; }}
                    />
                    <TextInput
                        style={[styles.modalInput, styles.modalArea]}
                        value={newDescription}
                        placeholder="What is this channel about? (optional)"
                        placeholderTextColor={C.muted}
                        multiline={True}
                        onChangeText={lambda (t: str) { newDescription = t; }}
                    />
                    <View style={styles.modalFooter}>
                        <Pressable
                            style={styles.ghostBtn}
                            onPress={lambda { showCreate = False; }}
                        >
                            <Text style={styles.ghostLabel}>Cancel</Text>
                        </Pressable>
                        <Pressable
                            style={[
                                styles.pillBtn,
                                (styles.btnDisabled if not newName.strip() else None)
                            ]}
                            disabled={not newName.strip()}
                            onPress={lambda { submitCreate(); }}
                        >
                            <Text style={styles.primaryLabel}>Create</Text>
                        </Pressable>
                    </View>
                </View>
            </View>
        </Modal>
        <ScrollView style={styles.body} contentContainerStyle={styles.scrollBody}>
            <Pressable style={styles.createRow} onPress={lambda { showCreate = True; }}>
                <Icon name="plus" size={18} color={C.accentText}/>
                <Text style={styles.primaryLabel}>Create channel</Text>
            </Pressable>
            {if loading and len(channels) == 0 {
                <LoadingRows count={3}/>
            } elif len(channels) == 0 {
                <EmptyState
                    icon="hash"
                    title="No channels yet"
                    hint="Create one to get the conversation started."
                />
            } else {
                for ch in channels {
                    <Pressable
                        style={styles.channelRow}
                        key={jid(ch.channel)}
                        onPress={lambda { onSelect(jid(ch.channel)); }}
                    >
                        <View style={styles.channelIcon}>
                            <Icon name="hash" size={20} color={C.accent}/>
                        </View>
                        <View style={styles.channelBody}>
                            <Text style={styles.channelName} numberOfLines={1}>
                                {ch.channel.name}
                            </Text>
                            {if ch.channel.description {
                                <Text style={styles.channelDesc} numberOfLines={1}>
                                    {ch.channel.description}
                                </Text>
                            }}
                            <View style={styles.channelMeta}>
                                <Icon name="users" size={12} color={C.muted}/>
                                <Text style={styles.channelMetaText}>
                                    {count_label(ch.member_count, "member", "members")}
                                </Text>
                            </View>
                        </View>
                        {if ch.is_member {
                            <View style={styles.badge}>
                                <Text style={styles.badgeText}>Joined</Text>
                            </View>
                        }}
                    </Pressable>
                }
            }  }
        </ScrollView>
    </View>
}
