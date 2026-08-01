import os;
import shutil;
import subprocess;
import from pathlib { Path }

glob _LIGHT_THEME: dict[str, str] = {
         "primary": "#2563eb",
         "onPrimary": "#ffffff",
         "secondary": "#4f46e5",
         "onSecondary": "#ffffff",
         "tertiary": "#0f766e",
         "onTertiary": "#ffffff",
         "muted": "#64748b",
         "onMuted": "#ffffff",
         "background": "#ffffff",
         "onBackground": "#111827",
         "surface": "#f8fafc",
         "onSurface": "#111827",
         "success": "#16a34a",
         "onSuccess": "#ffffff",
         "info": "#0284c7",
         "onInfo": "#ffffff",
         "warning": "#d97706",
         "onWarning": "#111827",
         "danger": "#dc2626",
         "onDanger": "#ffffff",
         "softPrimary": "#dbeafe",
         "onSoftPrimary": "#1e3a8a",
         "softSecondary": "#e0e7ff",
         "onSoftSecondary": "#312e81",
         "softTertiary": "#ccfbf1",
         "onSoftTertiary": "#134e4a",
         "softMuted": "#e2e8f0",
         "onSoftMuted": "#334155",
         "softSuccess": "#dcfce7",
         "onSoftSuccess": "#14532d",
         "softInfo": "#e0f2fe",
         "onSoftInfo": "#075985",
         "softWarning": "#fef3c7",
         "onSoftWarning": "#78350f",
         "softDanger": "#fee2e2",
         "onSoftDanger": "#7f1d1d"
     },
     _LIGHT_RADIUS: int = 8;

impl escape_kotlin(value: str) -> str {
    return (
        value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace(
            '$', '\\$'
        )
    );
}

impl escape_android_xml(value: str) -> str {
    return (
        value.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace(
            '"', '&quot;'
        ).replace(
            "'", "\\'"
        )
    );
}

impl package_to_path(package_name: str) -> str {
    return package_name.replace('.', '/');
}

impl android_color_literal(hex: str) -> str {
    raw = hex.strip().lstrip('#');
    if len(raw) == 6 {
        argb = f"FF{raw.upper()}";
    } elif len(raw) == 8 {
        argb = f"{raw[6:8].upper()}{raw[0:6].upper()}";
    } else {
        argb = raw.upper();
    }
    return f"Color(0x{argb})";
}

impl emit_jac_design -> str {
    lines: list[str] = [
        "object JacDesign {",
        '    var name by mutableStateOf("light")',
        "        private set"
    ];
    for (token, hex_val) in _LIGHT_THEME.items() {
        lines.append(
            f"    var {token} by mutableStateOf({android_color_literal(hex_val)})"
        );
        lines.append("        private set");
    }
    lines.append(f"    var radius by mutableStateOf({_LIGHT_RADIUS}.dp)");
    lines.append("        private set");
    lines.append("    fun applyTheme(themeName: String) {");
    lines.append(
        '        val theme = JacThemeModule.themes.firstOrNull { it.name == themeName } '
            + "?: JacThemeModule.themes.first { it.name == JacThemeModule.defaultTheme }"
    );
    lines.append("        name = theme.name");
    for token in _LIGHT_THEME.keys() {
        lit = android_color_literal(_LIGHT_THEME[token]);
        lines.append(f'        {token} = theme.colors["{token}"] ?: {lit}');
    }
    lines.append("        radius = theme.radius");
    lines.append("    }");
    lines.append("}");
    return '\n'.join(lines) + '\n';
}

def _settings_gradle(dev: bool = False) -> str {
    hot_include = '\ninclude(":hot")' if dev else "";
    return (
        "pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }\n"
        "dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); "
        "repositories { google(); mavenCentral() } }\n"
        'rootProject.name = "JacGeneratedAndroid"\n'
        'include(":app")'
        + hot_include
        + "\n"
    );
}

def _root_gradle -> str {
    return (
        "plugins {\n"
        '    id("com.android.application") version "8.13.1" apply false\n'
        '    id("org.jetbrains.kotlin.android") version "2.2.21" apply false\n'
        '    id("org.jetbrains.kotlin.plugin.compose") version "2.2.21" apply false\n'
        '    id("org.jetbrains.kotlin.plugin.serialization") version "2.2.21" apply false\n'
        "}\n"
    );
}

def _gradle_properties -> str {
    return (
        "android.useAndroidX=true\n"
        "kotlin.jvm.target.validation.mode=warning\n"
        "# --- Gradle caching ---\n"
        "# Reuse task outputs across builds / machines.\n"
        "org.gradle.caching=true\n"
        "# Skip re-evaluating the build scripts when nothing changed.\n"
        "org.gradle.configuration-cache=true\n"
        "# Parallel module builds + a warm daemon.\n"
        "org.gradle.parallel=true\n"
        "org.gradle.daemon=true\n"
        "# Kotlin incremental compilation + daemon.\n"
        "kotlin.daemon.enabled=true\n"
        "kotlin.incremental=true\n"
        "# Faster resource handling (defaults on modern AGP, pinned here).\n"
        "android.nonTransitiveRClass=true\n"
        "android.nonFinalResIds=true\n"
        "# Keep the daemon warm but bounded.\n"
        "org.gradle.jvmargs=-Xmx2g -XX:+UseParallelGC\n"
    );
}

def _app_gradle(package_name: str) -> str {
    pkg = escape_kotlin(package_name);
    return f"""plugins {{
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}}

android {{
    namespace = "{pkg}"
    compileSdk = 35

    defaultConfig {{
        applicationId = "{pkg}"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
    }}

    compileOptions {{
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }}
}}

kotlin {{
    compilerOptions {{
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }}
}}

dependencies {{
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.ui:ui")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}}
""";
}

def _hot_gradle(package_name: str) -> str {
    pkg = escape_kotlin(package_name);
    return f"""plugins {{
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}}

android {{
    namespace = "{pkg}"
    compileSdk = 35

    defaultConfig {{
        minSdk = 26
    }}

    compileOptions {{
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }}
}}

kotlin {{
    compilerOptions {{
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }}
}}

dependencies {{
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.ui:ui")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}}
""";
}

def _hot_manifest -> str {
    return '<manifest xmlns:android="http://schemas.android.com/apk/res/android" />\n';
}

def _android_manifest(app_name: str, dev: bool = False) -> str {
    label = escape_android_xml(app_name);
    dev_activity = (
        '        <activity android:name=".JacDevHostActivity" android:exported="true" android:windowSoftInputMode="adjustResize" android:configChanges="screenSize|smallestScreenSize|screenLayout|orientation">\n'
        '            <intent-filter>\n'
        '                <action android:name="android.intent.action.MAIN" />\n'
        '                <category android:name="android.intent.category.LAUNCHER" />\n'
        '            </intent-filter>\n'
        '        </activity>\n'
    )
        if dev
        else "";
    main_launcher = (
        ""
            if dev
            else (
                '            <intent-filter>\n'
                '                <action android:name="android.intent.action.MAIN" />\n'
                '                <category android:name="android.intent.category.LAUNCHER" />\n'
                '            </intent-filter>\n'
            )
    );
    return f"""<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application android:theme="@style/AppTheme" android:label="{label}" android:usesCleartextTraffic="true">
{dev_activity}        <activity android:name=".MainActivity" android:exported="true" android:windowSoftInputMode="adjustResize" android:supportsPictureInPicture="true" android:configChanges="screenSize|smallestScreenSize|screenLayout|orientation">
{main_launcher}            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="jac-dev" android:host="generated" />
            </intent-filter>
        </activity>
    </application>
</manifest>
""";
}

def _styles_xml -> str {
    return (
        "<resources>\n"
        '    <style name="AppTheme" parent="android:style/Theme.Material.Light.NoActionBar" />\n'
        "</resources>\n"
    );
}

def _strings_xml(app_name: str) -> str {
    return (
        "<resources>\n"
        f'    <string name="app_name">{escape_android_xml(app_name)}</string>\n'
        "</resources>\n"
    );
}

def _main_activity(package_name: str) -> str {
    return f"""package {package_name}

import android.content.Intent
import android.content.res.Configuration
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.luminance
import androidx.compose.material3.MaterialTheme
import androidx.core.view.WindowCompat

class MainActivity : ComponentActivity() {{
    private var incomingPath by mutableStateOf(JacRoutes.initialPath)
    private var incomingFragment by mutableStateOf<String?>(null)
    private var incomingRequest by mutableStateOf(0)

    override fun onCreate(savedInstanceState: Bundle?) {{
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        restoreThemePreference()
        applyIntentRoute(intent)
        setContent {{
            val useDarkSystemBarIcons = JacDesign.background.luminance() > 0.179f
            SideEffect {{
                WindowCompat.getInsetsController(window, window.decorView).apply {{
                    isAppearanceLightStatusBars = useDarkSystemBarIcons
                    isAppearanceLightNavigationBars = useDarkSystemBarIcons
                }}
            }}
            MaterialTheme {{
                JacApp(incomingPath, incomingFragment, incomingRequest)
            }}
        }}
    }}

    override fun onNewIntent(intent: Intent) {{
        super.onNewIntent(intent)
        setIntent(intent)
        applyIntentRoute(intent)
    }}

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {{
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
    }}

    private fun restoreThemePreference() {{
        val storedTheme = getSharedPreferences("jac", MODE_PRIVATE)
            .getString("theme-preference", JacThemeModule.defaultTheme)
            ?: JacThemeModule.defaultTheme
        JacDesign.applyTheme(storedTheme)
    }}

    private fun applyIntentRoute(intent: Intent?) {{
        val path = intent?.data?.path?.takeIf {{ JacRoutes.paths.contains(it) }} ?: JacRoutes.initialPath
        incomingPath = path
        incomingFragment = intent?.data?.fragment?.takeIf {{ JacRoutes.sections[path]?.contains(it) == true }}
        incomingRequest += 1
    }}
}}
""";
}

def _jac_routing(package_name: str, routes: list[str]) -> str {
    effective = routes or ["/"];
    route_lines = '\n'.join([f'    "{escape_kotlin(p)}",' for p in effective]);
    initial = effective[0];
    deep_lines = '\n'.join(
        [f'    "jac-dev://generated{"/" if p == "/" else p}",' for p in effective]
    );
    section_lines = '\n'.join(
        [f'    "{escape_kotlin(p)}" to listOf(),' for p in effective]
    );
    return f"""package {package_name}

object JacRoutes {{
    const val initialPath = "{escape_kotlin(initial)}"
    val paths = listOf(
{route_lines}
    )
    val sections: Map<String, List<String>> = mapOf(
{section_lines}
    )
    val deepLinks = listOf(
{deep_lines}
    )
}}
""";
}

def _jac_environment(package_name: str, backend_url: str) -> str {
    url = escape_kotlin(backend_url);
    return f"""package {package_name}

object JacEnvironment {{
    const val BACKEND_URL = "{url}"
}}
""";
}

def _theme_color_map_entries -> str {
    entries: list[str] = [];
    for (token, hex_val) in _LIGHT_THEME.items() {
        entries.append(f'            "{token}" to {android_color_literal(hex_val)},');
    }
    return '\n'.join(entries);
}

def _jac_theme(package_name: str) -> str {
    colors = _theme_color_map_entries();
    return f"""package {package_name}

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

data class JacGeneratedTheme(
    val name: String,
    val colors: Map<String, Color>,
    val radius: Dp
)

object JacThemeModule {{
    const val generated = true
    const val defaultTheme = "light"
    val names = listOf(
        "light",
    )
    val themes = listOf(
        JacGeneratedTheme(name = "light", colors = mapOf(
{colors}
        ), radius = {_LIGHT_RADIUS}.dp),
    )
}}
""";
}

def _jac_layouts(package_name: str) -> str {
    return f"""package {package_name}

import androidx.compose.runtime.Composable

@Composable
fun JacLayoutBoundary(content: @Composable () -> Unit) {{
    content()
}}
""";
}

def _jac_responsive(package_name: str) -> str {
    return f"""package {package_name}

object JacResponsiveModule {{
    const val generated = true
}}
""";
}

def _generated_views_index(package_name: str) -> str {
    return f"package {package_name}\n";
}

def _jac_dev_entry(package_name: str) -> str {
    return f"""package {package_name}

import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme

// Hot-swap entry point. In dev, JacDevHostActivity DexClassLoader-loads this
// class from a freshly compiled classes.dex and reflectively calls mount().
// In release, MainActivity could call the same method directly. Either way the
// composable tree is defined once, here.
object JacDevEntry {{
    @JvmStatic
    fun mount(activity: ComponentActivity) {{
        activity.setContent {{
            MaterialTheme {{
                JacApp(JacRoutes.initialPath, null, 0)
            }}
        }}
    }}
}}
""";
}

def _jac_dev_host_activity(package_name: str) -> str {
    return f"""package {package_name}

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.FrameLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import dalvik.system.DexClassLoader
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject

// On-device HMR host. Polls the Jac dev server for a new module version every
// 300ms, downloads the merged classes.dex, and DexClassLoader-swaps it WITHOUT
// reinstalling the APK. The loaded module's JacDevEntry.mount(this) installs the
// composable tree via setContent. (Kotlin/Compose port of the reference's dev host Activity.)
class JacDevHostActivity : ComponentActivity() {{
    private val handler = Handler(Looper.getMainLooper())
    private var endpoint: String = ""
    private var activeVersion: String = ""
    private var attemptedVersion: String = ""
    private var running: Boolean = true

    override fun onCreate(savedInstanceState: Bundle?) {{
        super.onCreate(savedInstanceState)
        endpoint = resolveEndpoint(intent)
        val loading = FrameLayout(this)
        val label = TextView(this)
        label.text = "Loading Jac module"
        loading.addView(label)
        setContentView(loading)
        restoreCachedModule()
        poll()
    }}

    override fun onNewIntent(intent: Intent) {{
        super.onNewIntent(intent)
        setIntent(intent)
        val resume = endpoint.isEmpty()
        endpoint = resolveEndpoint(intent)
        if (resume && endpoint.isNotEmpty()) {{
            poll()
        }}
    }}

    override fun onDestroy() {{
        running = false
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }}

    private fun resolveEndpoint(launchIntent: Intent?): String {{
        val value = launchIntent?.getStringExtra(EXTRA_SERVER)
        if (!value.isNullOrEmpty()) {{
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().putString(KEY_ENDPOINT, value).apply()
            return value
        }}
        return getSharedPreferences(PREFS, MODE_PRIVATE).getString(KEY_ENDPOINT, "") ?: ""
    }}

    private fun moduleDirectory(): File {{
        val dir = File(filesDir, "jac-modules")
        if (!dir.isDirectory && !dir.mkdirs()) {{
            throw IllegalStateException("unable to create Jac module directory")
        }}
        return dir
    }}

    private fun moduleFile(version: String): File {{
        return File(moduleDirectory(), "jac-module-" + version + ".dex")
    }}

    private fun restoreCachedModule() {{
        try {{
            val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
            val version = prefs.getString(KEY_PENDING_VERSION, null)
                ?: prefs.getString(KEY_VERSION, "")
            if (version.isNullOrEmpty()) return
            val module = moduleFile(version)
            if (!module.isFile) return
            module.setReadOnly()
            mountModule(module, version)
        }} catch (error: Exception) {{
            Log.e(TAG, "cached module restore failed", error)
        }}
    }}

    private fun poll() {{
        if (!running || endpoint.isEmpty()) return
        Thread {{
            try {{
                val manifest = readJson(endpoint + "/_jac/dev/modules/manifest.json")
                val version = manifest.optString("version", "")
                val path = manifest.optString("path", "")
                if (version.isNotEmpty() && version != activeVersion && version != attemptedVersion) {{
                    val module = download(endpoint + path, version)
                    handler.post {{ applyModule(module, version) }}
                }}
            }} catch (error: Exception) {{
                Log.e(TAG, "module poll failed", error)
            }}
            handler.postDelayed({{ poll() }}, 300)
        }}.start()
    }}

    private fun readJson(value: String): JSONObject {{
        val connection = URL(value).openConnection() as HttpURLConnection
        connection.useCaches = false
        connection.connectTimeout = 1000
        connection.readTimeout = 1000
        try {{
            return JSONObject(connection.inputStream.readBytes().toString(Charsets.UTF_8))
        }} finally {{
            connection.disconnect()
        }}
    }}

    private fun download(value: String, version: String): File {{
        val target = moduleFile(version)
        if (target.isFile) {{
            target.setReadOnly()
            return target
        }}
        val staged = File(moduleDirectory(), target.name + ".tmp")
        val connection = URL(value).openConnection() as HttpURLConnection
        connection.useCaches = false
        try {{
            connection.inputStream.use {{ input ->
                FileOutputStream(staged).use {{ output -> input.copyTo(output) }}
            }}
        }} finally {{
            connection.disconnect()
        }}
        if (!staged.renameTo(target)) {{
            throw IllegalStateException("unable to publish Jac module")
        }}
        target.setReadOnly()
        return target
    }}

    private fun applyModule(file: File, version: String) {{
        if (version == activeVersion) {{
            return
        }}
        if (version == attemptedVersion) {{
            return
        }}
        attemptedVersion = version
        if (activeVersion.isEmpty()) {{
            if (!mountModule(file, version)) {{
                attemptedVersion = ""
            }}
        }} else {{
            getSharedPreferences(PREFS, MODE_PRIVATE)
                .edit()
                .putString(KEY_PENDING_VERSION, version)
                .apply()
            recreate()
        }}
    }}

    private fun mountModule(file: File, version: String): Boolean {{
        try {{
            val loader = DexClassLoader(file.absolutePath, codeCacheDir.absolutePath, null, classLoader)
            val type = loader.loadClass("{package_name}.JacDevEntry")
            val mount = type.getMethod("mount", ComponentActivity::class.java)
            mount.invoke(null, this)
            activeVersion = version
            getSharedPreferences(PREFS, MODE_PRIVATE)
                .edit()
                .putString(KEY_VERSION, version)
                .remove(KEY_PENDING_VERSION)
                .apply()
            attemptedVersion = ""
            return true
        }} catch (error: Exception) {{
            Log.e(TAG, "module apply failed", error)
            file.delete()
            val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
            if (prefs.getString(KEY_VERSION, "") == version) {{
                prefs.edit().remove(KEY_VERSION).apply()
            }}
            prefs.edit().remove(KEY_PENDING_VERSION).apply()
            return false
        }}
    }}

    companion object {{
        private const val TAG = "JacHmr"
        private const val PREFS = "jac-hmr"
        private const val EXTRA_SERVER = "jacDevServer"
        private const val KEY_ENDPOINT = "endpoint"
        private const val KEY_VERSION = "version"
        private const val KEY_PENDING_VERSION = "pending_version"
    }}
}}
""";
}

impl GradleScaffold.generate -> dict[str, str] {
    return build_gradle_scaffold(
        self.package_name, self.app_name, self.backend_url, self.routes, self.dev
    );
}

impl build_gradle_scaffold(
    package_name: str,
    app_name: str,
    backend_url: str,
    routes: list[str],
    dev: bool = False
) -> dict[str, str] {
    pkg_path = package_to_path(package_name);
    base_root = f"app/src/main/java/{pkg_path}";
    hot_root = f"hot/src/main/java/{pkg_path}";
    effective_routes = routes or ["/"];
    infra_files: dict[str, str] = {
        "MainActivity.kt": _main_activity(package_name),
        "JacRouting.kt": _jac_routing(package_name, effective_routes),
        "JacEnvironment.kt": _jac_environment(package_name, backend_url),
        "JacTheme.kt": _jac_theme(package_name),
        "JacLayouts.kt": _jac_layouts(package_name),
        "JacResponsive.kt": _jac_responsive(package_name),
        "GeneratedViews.kt": _generated_views_index(package_name)
    };
    files: dict[str, str] = {
        "build.gradle.kts": _root_gradle(),
        "gradle.properties": _gradle_properties(),
        "app/build.gradle.kts": _app_gradle(package_name),
        "app/src/main/res/values/styles.xml": _styles_xml(),
        "app/src/main/res/values/strings.xml": _strings_xml(app_name)
    };
    if dev {
        files["settings.gradle.kts"] = _settings_gradle(dev=True);
        files["app/src/main/AndroidManifest.xml"] = _android_manifest(
            app_name, dev=True
        );
        files["hot/build.gradle.kts"] = _hot_gradle(package_name);
        files["hot/src/main/AndroidManifest.xml"] = _hot_manifest();
        files[f"{base_root}/JacDevHostActivity.kt"] = _jac_dev_host_activity(
            package_name
        );
        for (name, content) in infra_files.items() {
            files[f"{hot_root}/{name}"] = content;
        }
        files[f"{hot_root}/JacDevEntry.kt"] = _jac_dev_entry(package_name);
    } else {
        files["settings.gradle.kts"] = _settings_gradle(dev=False);
        files["app/src/main/AndroidManifest.xml"] = _android_manifest(
            app_name, dev=False
        );
        for (name, content) in infra_files.items() {
            files[f"{base_root}/{name}"] = content;
        }
    }
    return files;
}

impl ensure_gradle_wrapper(android_dir: Path) -> None {
    gradlew = android_dir / ("gradlew.bat" if os.name == "nt" else "gradlew");
    if gradlew.exists() {
        return;
    }
    gradle = shutil.which("gradle");
    if not gradle {
        return;
    }
    subprocess.run(
        [gradle, "wrapper", "--gradle-version", "8.13"],
        cwd=str(android_dir),
        check=False
    );
    if os.name != "nt" and gradlew.exists() {
        try {
            os.chmod(gradlew, 0o755);
        } except Exception { }
    }
}
