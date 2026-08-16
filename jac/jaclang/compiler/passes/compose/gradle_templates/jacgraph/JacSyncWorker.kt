package {{package}}

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

/** WorkManager worker that flushes the local oplog and merges remote ops. */
class JacSyncWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        return try {
            JacSync.runSync()
            Result.success()
        } catch (_: Exception) {
            Result.retry()
        }
    }
}
