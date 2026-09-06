import from "@jac/mobui" { View, Text, Pressable }
import from core.socialize_mobile.theme { C, styles }
import from core.socialize_mobile.icon { Icon }

def:pub BridgeBanner(
    message: str,
    canRetry: bool,
    onRetry: Callable[[], None],
    onDismiss: Callable[[], None],
) -> JsxElement {
    <View style={styles.banner}>
        <Icon name="offline" size={18} color={C.danger}/>
        <Text style={styles.bannerText}>{message}</Text>
        {if canRetry {
            <Pressable style={styles.bannerAction} onPress={lambda { onRetry(); }}>
                <Icon name="refresh" size={15} color={C.text}/>
                <Text style={styles.bannerActionLabel}>Retry</Text>
            </Pressable>
        }}
        <Pressable style={styles.bannerClose} onPress={lambda { onDismiss(); }}>
            <Icon name="close" size={16} color={C.muted}/>
        </Pressable>
    </View>
}
