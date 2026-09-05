import from "@jac/mobui" { View, Text, Pressable, TextInput, ActivityIndicator }
import from mobile.theme { C, styles }
import from mobile.format { chars_left }
import from .Avatar { Avatar }

def:pub Composer(
    username: str,
    placeholder: str,
    value: str,
    onChange: Callable[[str], None],
    onPost: Callable[[], None],
    busy: bool = False,
    buttonLabel: str = "Post",
) -> JsxElement {
    remaining = chars_left(value);
    can_post = value.strip() != "" and remaining >= 0 and not busy;

    <View style={styles.composer}>
        <Avatar username={username} size={42}/>
        <View style={styles.composerCol}>
            <TextInput
                style={styles.composerInput}
                value={value}
                placeholder={placeholder}
                placeholderTextColor={C.muted}
                multiline={True}
                onChangeText={onChange}
            />
            <View style={styles.composerFooter}>
                {if len(value) > 0 {
                    <Text
                        style={styles.counterWarn if remaining < 20 else styles.counter}
                    >
                        {str(remaining)}
                    </Text>
                }}
                <Pressable
                    style={[
                        styles.pillBtn,
                        (styles.btnDisabled if not can_post else None)
                    ]}
                    disabled={not can_post}
                    onPress={lambda { onPost(); }}
                >
                    {if busy {
                        <ActivityIndicator size="small" color={C.accentText}/>
                    } else {
                        <Text style={styles.primaryLabel}>{buttonLabel}</Text>
                    } }
                </Pressable>
            </View>
        </View>
    </View>
}
