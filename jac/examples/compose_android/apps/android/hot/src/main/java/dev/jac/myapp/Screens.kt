package dev.jac.myapp

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.ScrollState
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.activity.compose.BackHandler
import android.content.Intent
import android.net.Uri
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.launch

object JacDesign {
    var name by mutableStateOf("light")
        private set
    var primary by mutableStateOf(Color(0xFF2563EB))
        private set
    var onPrimary by mutableStateOf(Color(0xFFFFFFFF))
        private set
    var secondary by mutableStateOf(Color(0xFF4F46E5))
        private set
    var onSecondary by mutableStateOf(Color(0xFFFFFFFF))
        private set
    var tertiary by mutableStateOf(Color(0xFF0F766E))
        private set
    var onTertiary by mutableStateOf(Color(0xFFFFFFFF))
        private set
    var muted by mutableStateOf(Color(0xFF64748B))
        private set
    var onMuted by mutableStateOf(Color(0xFFFFFFFF))
        private set
    var background by mutableStateOf(Color(0xFFFFFFFF))
        private set
    var onBackground by mutableStateOf(Color(0xFF111827))
        private set
    var surface by mutableStateOf(Color(0xFFF8FAFC))
        private set
    var onSurface by mutableStateOf(Color(0xFF111827))
        private set
    var success by mutableStateOf(Color(0xFF16A34A))
        private set
    var onSuccess by mutableStateOf(Color(0xFFFFFFFF))
        private set
    var info by mutableStateOf(Color(0xFF0284C7))
        private set
    var onInfo by mutableStateOf(Color(0xFFFFFFFF))
        private set
    var warning by mutableStateOf(Color(0xFFD97706))
        private set
    var onWarning by mutableStateOf(Color(0xFF111827))
        private set
    var danger by mutableStateOf(Color(0xFFDC2626))
        private set
    var onDanger by mutableStateOf(Color(0xFFFFFFFF))
        private set
    var softPrimary by mutableStateOf(Color(0xFFDBEAFE))
        private set
    var onSoftPrimary by mutableStateOf(Color(0xFF1E3A8A))
        private set
    var softSecondary by mutableStateOf(Color(0xFFE0E7FF))
        private set
    var onSoftSecondary by mutableStateOf(Color(0xFF312E81))
        private set
    var softTertiary by mutableStateOf(Color(0xFFCCFBF1))
        private set
    var onSoftTertiary by mutableStateOf(Color(0xFF134E4A))
        private set
    var softMuted by mutableStateOf(Color(0xFFE2E8F0))
        private set
    var onSoftMuted by mutableStateOf(Color(0xFF334155))
        private set
    var softSuccess by mutableStateOf(Color(0xFFDCFCE7))
        private set
    var onSoftSuccess by mutableStateOf(Color(0xFF14532D))
        private set
    var softInfo by mutableStateOf(Color(0xFFE0F2FE))
        private set
    var onSoftInfo by mutableStateOf(Color(0xFF075985))
        private set
    var softWarning by mutableStateOf(Color(0xFFFEF3C7))
        private set
    var onSoftWarning by mutableStateOf(Color(0xFF78350F))
        private set
    var softDanger by mutableStateOf(Color(0xFFFEE2E2))
        private set
    var onSoftDanger by mutableStateOf(Color(0xFF7F1D1D))
        private set
    var radius by mutableStateOf(8.dp)
        private set
    fun applyTheme(themeName: String) {
        val theme = JacThemeModule.themes.firstOrNull { it.name == themeName } ?: JacThemeModule.themes.first { it.name == JacThemeModule.defaultTheme }
        name = theme.name
        primary = theme.colors["primary"] ?: Color(0xFF2563EB)
        onPrimary = theme.colors["onPrimary"] ?: Color(0xFFFFFFFF)
        secondary = theme.colors["secondary"] ?: Color(0xFF4F46E5)
        onSecondary = theme.colors["onSecondary"] ?: Color(0xFFFFFFFF)
        tertiary = theme.colors["tertiary"] ?: Color(0xFF0F766E)
        onTertiary = theme.colors["onTertiary"] ?: Color(0xFFFFFFFF)
        muted = theme.colors["muted"] ?: Color(0xFF64748B)
        onMuted = theme.colors["onMuted"] ?: Color(0xFFFFFFFF)
        background = theme.colors["background"] ?: Color(0xFFFFFFFF)
        onBackground = theme.colors["onBackground"] ?: Color(0xFF111827)
        surface = theme.colors["surface"] ?: Color(0xFFF8FAFC)
        onSurface = theme.colors["onSurface"] ?: Color(0xFF111827)
        success = theme.colors["success"] ?: Color(0xFF16A34A)
        onSuccess = theme.colors["onSuccess"] ?: Color(0xFFFFFFFF)
        info = theme.colors["info"] ?: Color(0xFF0284C7)
        onInfo = theme.colors["onInfo"] ?: Color(0xFFFFFFFF)
        warning = theme.colors["warning"] ?: Color(0xFFD97706)
        onWarning = theme.colors["onWarning"] ?: Color(0xFF111827)
        danger = theme.colors["danger"] ?: Color(0xFFDC2626)
        onDanger = theme.colors["onDanger"] ?: Color(0xFFFFFFFF)
        softPrimary = theme.colors["softPrimary"] ?: Color(0xFFDBEAFE)
        onSoftPrimary = theme.colors["onSoftPrimary"] ?: Color(0xFF1E3A8A)
        softSecondary = theme.colors["softSecondary"] ?: Color(0xFFE0E7FF)
        onSoftSecondary = theme.colors["onSoftSecondary"] ?: Color(0xFF312E81)
        softTertiary = theme.colors["softTertiary"] ?: Color(0xFFCCFBF1)
        onSoftTertiary = theme.colors["onSoftTertiary"] ?: Color(0xFF134E4A)
        softMuted = theme.colors["softMuted"] ?: Color(0xFFE2E8F0)
        onSoftMuted = theme.colors["onSoftMuted"] ?: Color(0xFF334155)
        softSuccess = theme.colors["softSuccess"] ?: Color(0xFFDCFCE7)
        onSoftSuccess = theme.colors["onSoftSuccess"] ?: Color(0xFF14532D)
        softInfo = theme.colors["softInfo"] ?: Color(0xFFE0F2FE)
        onSoftInfo = theme.colors["onSoftInfo"] ?: Color(0xFF075985)
        softWarning = theme.colors["softWarning"] ?: Color(0xFFFEF3C7)
        onSoftWarning = theme.colors["onSoftWarning"] ?: Color(0xFF78350F)
        softDanger = theme.colors["softDanger"] ?: Color(0xFFFEE2E2)
        onSoftDanger = theme.colors["onSoftDanger"] ?: Color(0xFF7F1D1D)
        radius = theme.radius
    }
}


class JacSectionRegistry {
    val positions = mutableMapOf<String, Int>()
}

private data class JacRouteEntry(val path: String, val fragment: String?)


@Composable
fun JacApp(startPath: String = JacRoutes.initialPath, startFragment: String? = null, navigationRequest: Int = 0) {
    val context = LocalContext.current
    val hmr = context.getSharedPreferences("jac-hmr", android.content.Context.MODE_PRIVATE)
    val restoredPath = hmr.getString("path", null)?.takeIf { JacRoutes.paths.contains(it) }
    val initialPath = restoredPath ?: (if (JacRoutes.paths.contains(startPath)) startPath else JacRoutes.initialPath)
    val initialFragment = startFragment?.takeIf { JacRoutes.sections[initialPath]?.contains(it) == true }
    var currentEntry by remember { mutableStateOf(JacRouteEntry(initialPath, initialFragment)) }
    var externalUrl by remember { mutableStateOf<String?>(null) }
    val backStack = remember { mutableStateListOf<JacRouteEntry>() }
    val scrollState = rememberScrollState()
    val sectionRegistry = remember(currentEntry.path) { JacSectionRegistry() }
    fun navigate(operation: String, target: String, fragment: String?) {
        val path = target.ifEmpty { currentEntry.path }
        if (!JacRoutes.paths.contains(path)) {
            return
        }
        val destination = JacRouteEntry(path, fragment?.takeIf { JacRoutes.sections[path]?.contains(it) == true })
        if (destination == currentEntry) {
            return
        }
        if (operation == "replace") {
            currentEntry = destination
        } else {
            backStack.add(currentEntry)
            currentEntry = destination
        }
    }
    fun goBack() {
        if (externalUrl != null) {
            externalUrl = null
        } else if (backStack.isNotEmpty()) {
            currentEntry = backStack.removeAt(backStack.lastIndex)
        } else if (currentEntry.path != JacRoutes.initialPath || currentEntry.fragment != null) {
            currentEntry = JacRouteEntry(JacRoutes.initialPath, null)
        }
    }
    fun openExternal(mode: String, target: String) {
        if (mode == "webview") {
            externalUrl = target
        } else {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(target)))
        }
    }
    LaunchedEffect(navigationRequest) {
        navigate("replace", initialPath, initialFragment)
    }
    LaunchedEffect(currentEntry.path) {
        hmr.edit().putString("path", currentEntry.path).apply()
    }
    LaunchedEffect(currentEntry.path) {
        scrollState.scrollTo(0)
    }
    BackHandler(enabled = true) {
        goBack()
    }
    Box(modifier = Modifier.fillMaxSize().background(JacDesign.background)) {
        BoxWithConstraints(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.TopStart) {
            val viewportWidth = maxWidth
            when (currentEntry.path) {
                    "/" -> Box(modifier = Modifier.fillMaxSize().verticalScroll(scrollState)) { HomeScreen(viewportWidth, scrollState, sectionRegistry, ::navigate, ::goBack, ::openExternal) }
                    else -> Box(modifier = Modifier.fillMaxSize().verticalScroll(scrollState)) { HomeScreen(viewportWidth, scrollState, sectionRegistry, ::navigate, ::goBack, ::openExternal) }
            }
        }
    }
}


@Composable
fun HomeScreen(viewportWidth: Dp, scrollState: ScrollState, sectionRegistry: JacSectionRegistry, navigate: (String, String, String?) -> Unit, goBack: () -> Unit, openExternal: (String, String) -> Unit) {
    val scope = rememberCoroutineScope()
    var count by remember { mutableStateOf(0) }
    var name by remember { mutableStateOf("") }
    var greeting by remember { mutableStateOf("Tap Say hello") }
    Column() {
        /* unsupported component: Column */
        Column() {
            /* unsupported component: Text */
            Text(text = "\"Jac → Jetpack Compose\"")
        }
        Column() {
            /* unsupported component: Column */
            Column() {
                /* unsupported component: Text */
                Text(text = "\"Counter\"")
            }
            Column() {
                /* unsupported component: Text */
                Text(text = (count).toString())
            }
            Column() {
                /* unsupported component: Row */
                Button(onClick = {
                    count = (count + 1)
                }) {
                    Column() {
                        /* unsupported component: Text */
                        Text(text = "\"Increment\"")
                    }
                }
                Button(onClick = {
                    count = 0
                }) {
                    Column() {
                        /* unsupported component: Text */
                        Text(text = "\"Reset\"")
                    }
                }
            }
        }
        Column() {
            /* unsupported component: Column */
            Column() {
                /* unsupported component: Text */
                Text(text = "\"Greeting (typed RPC)\"")
            }
            Column() {
                /* unsupported component: OutlinedTextField */
            }
            Button(onClick = {
                scope.launch() {
                                    var next_greeting = "Empty response"
                                    try {
                                            var result = JacClient.greet(GreetRequest(name = name))
                                            if (result.reports.len > 0) {
                            next_greeting = result.reports[0]
                        }
                    } catch (__jac_e: Exception) {
                                            if (true) {
                            next_greeting = "Request failed — is jac serve running?"
                        } else {
                                                    throw __jac_e
                        }
                    }
                    greeting = next_greeting
                }
            }) {
                Column() {
                    /* unsupported component: Text */
                    Text(text = "\"Say hello\"")
                }
            }
            Column() {
                /* unsupported component: Text */
                Text(text = (greeting).toString())
            }
        }
    }
}
