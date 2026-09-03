import from "@jac/mobui" { View, Text }
import from mobile.theme { C, styles }
import from mobile.icon { Icon }

def:pub EmptyState(icon: str, title: str, hint: str) -> JsxElement {
    <View style={styles.empty}>
        <Icon name={icon} size={30} color={C.muted}/>
        <Text style={styles.emptyTitle}>{title}</Text>
        <Text style={styles.emptyText}>{hint}</Text>
    </View>
}

def:pub LoadingRows(count: int) -> JsxElement {
    <View style={styles.skeletonList}>
        {[
            <View style={styles.skeletonRow} key={i}>
                <View style={styles.skeletonAvatar}/>
                <View style={styles.skeletonBody}>
                    <View style={[styles.skeletonLine, {"width": "40%"}]}/>
                    <View style={styles.skeletonLine}/>
                    <View style={[styles.skeletonLine, {"width": "70%"}]}/>
                </View>
            </View> for i in range(count)
        ]}
    </View>
}
