package dev.jac.myapp

import androidx.compose.runtime.Composable

@Composable
fun JacLayoutBoundary(content: @Composable () -> Unit) {
    content()
}
