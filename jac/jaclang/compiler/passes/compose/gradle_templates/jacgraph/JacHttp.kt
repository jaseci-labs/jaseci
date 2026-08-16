package {{package}}

import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/** Shared HTTP POST helper for RemoteBackend walker RPC and local-first sync. */
object JacHttp {
    val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    suspend fun postJson(url: String, body: String, token: String? = null): Pair<Int, String> =
        withContext(Dispatchers.IO) {
            val conn = (URL(url).openConnection() as HttpURLConnection)
            try {
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.setRequestProperty("Accept", "application/json")
                token?.let { conn.setRequestProperty("Authorization", "Bearer $it") }
                conn.doOutput = true
                conn.outputStream.use { it.write(body.toByteArray()) }
                val code = conn.responseCode
                val stream = if (code in 200..299) conn.inputStream else conn.errorStream
                val responseBody = stream?.bufferedReader()?.readText() ?: ""
                code to responseBody
            } finally {
                conn.disconnect()
            }
        }

    suspend inline fun <reified Req> postJson(url: String, req: Req, token: String? = null): Pair<Int, String> =
        postJson(url, json.encodeToString(req), token)
}
