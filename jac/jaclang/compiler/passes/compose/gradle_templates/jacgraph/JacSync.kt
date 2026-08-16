package {{package}}

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.UUID
import java.util.concurrent.TimeUnit
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.decodeFromJsonElement

/**
 * Local-first sync orchestration and conflict policy.
 *
 * First cut: last-writer-wins per anchor by [GraphOp.logicalClock]. Deletes are
 * tombstones and win over concurrent field edits when the delete clock is >= the
 * anchor's local clock. Replace this object to swap merge strategies.
 */
object JacSync {
    private var appContext: Context? = null
    private var syncUrl: String = ""
    private val deviceId: String by lazy { UUID.randomUUID().toString() }

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    fun init(context: Context, url: String) {
        appContext = context.applicationContext
        syncUrl = url.trimEnd('/')
    }

    fun schedulePeriodicSync(context: Context) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            "jac_sync_periodic",
            ExistingPeriodicWorkPolicy.KEEP,
            PeriodicWorkRequestBuilder<JacSyncWorker>(15, TimeUnit.MINUTES)
                .setConstraints(constraints)
                .build(),
        )
    }

    fun requestSync() {
        val ctx = appContext ?: return
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        WorkManager.getInstance(ctx).enqueueUniqueWork(
            "jac_sync_now",
            ExistingWorkPolicy.KEEP,
            OneTimeWorkRequestBuilder<JacSyncWorker>()
                .setConstraints(constraints)
                .build(),
        )
    }

    suspend fun runSync() {
        if (syncUrl.isBlank()) {
            return
        }
        val pending = JacGraph.pendingOpsSnapshot()
        val request = SyncPushRequest(
            deviceId = deviceId,
            lastSyncedClock = JacGraph.lastSyncedClockValue(),
            ops = pending,
        )
        val (code, body) = JacHttp.postJson("$syncUrl/sync", request)
        if (code !in 200..299) {
            throw RuntimeException("JacSync HTTP $code: $body")
        }
        val response = json.decodeFromJsonElement<SyncPushResponse>(
            JacHttp.json.parseToJsonElement(body),
        )
        applyRemoteOps(response.ops)
        JacGraph.markOpsSynced(response.remoteClock)
        JacGraph.persist()
    }

    fun applyRemoteOps(remoteOps: List<GraphOp>) {
        for (op in remoteOps.sortedBy { it.logicalClock }) {
            applyRemoteOp(op)
        }
    }

    private fun applyRemoteOp(op: GraphOp) {
        when (op.kind) {
            "delete" -> applyDelete(op)
            "spawn" -> applySpawn(op)
            "connect" -> JacGraph.applyRemoteOpWithoutRecording(op)
            else -> { }
        }
    }

    private fun applyDelete(op: GraphOp) {
        // Tombstone deletes win over concurrent edits at the same or higher clock.
        JacGraph.applyRemoteOpWithoutRecording(op)
    }

    private fun applySpawn(op: GraphOp) {
        // Last-writer-wins per anchor: higher logical clock replaces local node state.
        JacGraph.applyRemoteOpWithoutRecording(op)
    }
}

@Serializable
data class SyncPushRequest(
    val deviceId: String,
    val lastSyncedClock: Long,
    val ops: List<GraphOp>,
)

@Serializable
data class SyncPushResponse(
    val remoteClock: Long,
    val ops: List<GraphOp> = emptyList(),
)
