package dev.jac.myapp

import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent

// Hot-swap entry point. In dev, JacDevHostActivity DexClassLoader-loads this
// class from a freshly compiled classes.dex and reflectively calls mount().
// In release, MainActivity could call the same method directly. Either way the
// composable tree is defined once, here.
object JacDevEntry {
    @JvmStatic
    fun mount(activity: ComponentActivity) {
        activity.setContent {
            JacApp(JacRoutes.initialPath, null, 0)
        }
    }
}
