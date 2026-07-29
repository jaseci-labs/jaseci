package dev.jac.myapp

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

data class JacGeneratedTheme(
    val name: String,
    val colors: Map<String, Color>,
    val radius: Dp
)

object JacThemeModule {
    const val generated = true
    const val defaultTheme = "light"
    val names = listOf(
        "light",
    )
    val themes = listOf(
        JacGeneratedTheme(name = "light", colors = mapOf(
            "primary" to Color(0xFF2563EB),
            "onPrimary" to Color(0xFFFFFFFF),
            "secondary" to Color(0xFF4F46E5),
            "onSecondary" to Color(0xFFFFFFFF),
            "tertiary" to Color(0xFF0F766E),
            "onTertiary" to Color(0xFFFFFFFF),
            "muted" to Color(0xFF64748B),
            "onMuted" to Color(0xFFFFFFFF),
            "background" to Color(0xFFFFFFFF),
            "onBackground" to Color(0xFF111827),
            "surface" to Color(0xFFF8FAFC),
            "onSurface" to Color(0xFF111827),
            "success" to Color(0xFF16A34A),
            "onSuccess" to Color(0xFFFFFFFF),
            "info" to Color(0xFF0284C7),
            "onInfo" to Color(0xFFFFFFFF),
            "warning" to Color(0xFFD97706),
            "onWarning" to Color(0xFF111827),
            "danger" to Color(0xFFDC2626),
            "onDanger" to Color(0xFFFFFFFF),
            "softPrimary" to Color(0xFFDBEAFE),
            "onSoftPrimary" to Color(0xFF1E3A8A),
            "softSecondary" to Color(0xFFE0E7FF),
            "onSoftSecondary" to Color(0xFF312E81),
            "softTertiary" to Color(0xFFCCFBF1),
            "onSoftTertiary" to Color(0xFF134E4A),
            "softMuted" to Color(0xFFE2E8F0),
            "onSoftMuted" to Color(0xFF334155),
            "softSuccess" to Color(0xFFDCFCE7),
            "onSoftSuccess" to Color(0xFF14532D),
            "softInfo" to Color(0xFFE0F2FE),
            "onSoftInfo" to Color(0xFF075985),
            "softWarning" to Color(0xFFFEF3C7),
            "onSoftWarning" to Color(0xFF78350F),
            "softDanger" to Color(0xFFFEE2E2),
            "onSoftDanger" to Color(0xFF7F1D1D),
        ), radius = 8.dp),
    )
}
