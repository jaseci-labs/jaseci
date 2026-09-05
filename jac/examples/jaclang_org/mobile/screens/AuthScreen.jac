import from "@jac/mobui" {
    View,
    Text,
    Pressable,
    TextInput,
    KeyboardAvoidingView,
    ActivityIndicator,
    Platform
}
import from mobile.theme { C, styles }
import from mobile.icon { Icon }

def:pub AuthScreen(
    isSignup: bool,
    username: str,
    password: str,
    error: str,
    loading: bool,
    onUsernameChange: Callable[[str], None],
    onPasswordChange: Callable[[str], None],
    onSubmit: Callable[[], None],
    onToggleMode: Callable[[], None],
) -> JsxElement {
    can_submit = username.strip() != "" and password != "" and not loading;

    <KeyboardAvoidingView
        style={styles.root}
        behavior={"padding" if Platform.OS == "ios" else "height"}
    >
        <View style={styles.authWrap}>
            <View style={styles.brandMark}>
                <Icon name="feather" size={30} color={C.accentText}/>
            </View>
            <Text style={styles.authTitle}>
                {"Create your account" if isSignup else "Welcome back"}
            </Text>
            <Text style={styles.authSub}>
                {"Join the conversation on Socialize"
                    if isSignup
                    else "Sign in to your Socialize account"}
            </Text>
            {if error {
                <View style={styles.errorBox}>
                    <Text style={styles.errorText}>{error}</Text>
                </View>
            }}
            <View style={styles.fieldRow}>
                <Icon name="at" size={18} color={C.muted}/>
                <TextInput
                    style={styles.fieldInput}
                    value={username}
                    placeholder="Username"
                    placeholderTextColor={C.muted}
                    autoCapitalize="none"
                    autoCorrect={False}
                    onChangeText={onUsernameChange}
                />
            </View>
            <View style={styles.fieldRow}>
                <Icon name="lock" size={18} color={C.muted}/>
                <TextInput
                    style={styles.fieldInput}
                    value={password}
                    placeholder="Password"
                    placeholderTextColor={C.muted}
                    secureTextEntry={True}
                    onChangeText={onPasswordChange}
                    onSubmitEditing={lambda { if can_submit { onSubmit(); }}}
                />
            </View>
            <Pressable
                style={[
                    styles.primaryBtn,
                    (styles.btnDisabled if not can_submit else None)
                ]}
                disabled={not can_submit}
                onPress={lambda { onSubmit(); }}
            >
                {if loading {
                    <ActivityIndicator size="small" color={C.accentText}/>
                } else {
                    <Text style={styles.primaryLabel}>
                        {"Sign up" if isSignup else "Log in"}
                    </Text>
                } }
            </Pressable>
            <View style={styles.switchRow}>
                <Text style={styles.switchText}>
                    {"Already have an account?" if isSignup else "New to Socialize?"}
                </Text>
                <Pressable onPress={lambda { onToggleMode(); }}>
                    <Text style={styles.switchLink}>
                        {"Log in" if isSignup else "Sign up"}
                    </Text>
                </Pressable>
            </View>
            <Text style={styles.footnote}>
                Same accounts and the same graph as jaclang.org/socialize.
            </Text>
        </View>
    </KeyboardAvoidingView>
}
