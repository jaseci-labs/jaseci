import from "@jac/mobui" { Image }
import from core.socialize_mobile.theme { styles }
import from core.socialize_mobile.format { avatar_url }

def:pub Avatar(username: str, size: int) -> JsxElement {
    <Image
        source={{"uri": avatar_url(username)}}
        style={[
            styles.avatar,
            {"width": size, "height": size, "borderRadius": int(size / 2)}
        ]}
    />
}
