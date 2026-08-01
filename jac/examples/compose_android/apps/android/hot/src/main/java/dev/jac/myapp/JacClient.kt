package dev.jac.myapp

import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.jsonObject

@Serializable
data class GreetRequest(
    val name: String = "friend"
)


@Serializable
data class GreetResponse(
    val reports: List<String> = emptyList()
)


object JacClient {
    @PublishedApi
    internal val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    var baseUrl: String = JacEnvironment.BACKEND_URL
    var token: String? = null

    suspend inline fun <reified Req, reified Res> call(
        walker: String,
        req: Req,
        nodeId: String? = null
    ): Res = withContext(Dispatchers.IO) {
        val suffix = nodeId?.let { "/$it" } ?: ""
        val url = URL(baseUrl + "/walker/" + walker + suffix)
        (url.openConnection() as HttpURLConnection).run {
            requestMethod = "POST"
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Accept", "application/json")
            token?.let { setRequestProperty("Authorization", "Bearer $it") }
            doOutput = true
            outputStream.use { it.write(json.encodeToString(req).toByteArray()) }
            val code = responseCode
            val stream = if (code in 200..299) inputStream else errorStream
            val body = stream?.bufferedReader()?.readText() ?: ""
            if (code == 401) {
                token = null
            }
            if (code !in 200..299) {
                throw RuntimeException("JacClient HTTP $code: $body")
            }
            val data = json.parseToJsonElement(body).jsonObject["data"]
                ?: throw RuntimeException("JacClient: missing data field")
            json.decodeFromJsonElement<Res>(data)
        }
    }

    suspend fun greet(req: GreetRequest, nodeId: String? = null): GreetResponse = call("greet", req, nodeId)
}
