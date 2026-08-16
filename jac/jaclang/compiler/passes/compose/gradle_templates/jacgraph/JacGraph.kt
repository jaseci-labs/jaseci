package {{package}}

import android.content.Context
import java.io.File
import java.util.UUID
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

/**
 * In-memory graph store for on-device walker execution.
 *
 * Persistence (Phase 3): a single JSON snapshot in app-internal storage
 * ([Context.filesDir]/jac_graph.json). No schema migrations — trade simplicity over
 * Room/SQLite until dataset size forces a richer store.
 *
 * Oplog (Phase 4): append-only mutation log at jac_oplog.json for local-first sync.
 */
@Serializable
data class EdgeSnapshot(val from: String, val to: String)

@Serializable
data class GraphSnapshot(
    val nodes: List<JsonObject> = emptyList(),
    val edges: List<EdgeSnapshot> = emptyList(),
)

@Serializable
data class GraphOp(
    val opId: String,
    val anchorId: String,
    val kind: String,
    val payload: JsonObject = JsonObject(emptyMap()),
    val logicalClock: Long,
)

@Serializable
data class OplogSnapshot(
    val logicalClock: Long = 0,
    val lastSyncedClock: Long = 0,
    val pendingOps: List<GraphOp> = emptyList(),
    val anchorClocks: Map<String, Long> = emptyMap(),
    val tombstones: Set<String> = emptySet(),
)

object JacGraph {
    private val nodes = mutableMapOf<String, Node>()
    private val outEdges = mutableMapOf<String, MutableList<String>>()
    private var appContext: Context? = null
    private var logicalClock: Long = 0
    private var lastSyncedClock: Long = 0
    private val pendingOps = mutableListOf<GraphOp>()
    private val anchorClocks = mutableMapOf<String, Long>()
    private val tombstones = mutableSetOf<String>()

    private val json by lazy {
        Json {
            ignoreUnknownKeys = true
            classDiscriminator = "kind"
            serializersModule = JacGraphSerializers.buildModule()
        }
    }

    val root: Node = RootNode()

    init {
        nodes[root.id] = root
    }

    fun init(context: Context) {
        appContext = context.applicationContext
        load()
    }

    fun <T : Node> spawnNode(node: T): T {
        nodes[node.id] = node
        tombstones.remove(node.id)
        recordOp(
            anchorId = node.id,
            kind = "spawn",
            payload = json.encodeToJsonElement(node) as JsonObject,
        )
        return node
    }

    fun connect(from: Node, to: Node) {
        outEdges.getOrPut(from.id) { mutableListOf() }.add(to.id)
        recordOp(
            anchorId = from.id,
            kind = "connect",
            payload = buildJsonObject {
                put("from", from.id)
                put("to", to.id)
            },
        )
    }

    fun neighbors(from: Node, dir: Dir, type: String? = null): List<Node> {
        if (dir != Dir.OUT) {
            throw UnsupportedOperationException("JacGraph.neighbors: only Dir.OUT is supported")
        }
        val ids = outEdges[from.id] ?: emptyList()
        return ids.mapNotNull { nodes[it] }.filter { type == null || it.type == type }
    }

    fun delete(node: Node) {
        if (node.id == root.id) {
            return
        }
        nodes.remove(node.id)
        outEdges.values.forEach { list -> list.remove(node.id) }
        outEdges.remove(node.id)
        tombstones.add(node.id)
        recordOp(
            anchorId = node.id,
            kind = "delete",
            payload = buildJsonObject { put("id", node.id) },
        )
    }

    fun byId(id: String): Node? = nodes[id]

    fun persist() {
        val ctx = appContext ?: return
        val nodeSnapshots = nodes.values
            .filter { it.id != root.id }
            .map { json.encodeToJsonElement(it) as JsonObject }
        val edgeSnapshots = outEdges.flatMap { (from, toIds) ->
            toIds.map { EdgeSnapshot(from, it) }
        }
        val snapshot = GraphSnapshot(nodeSnapshots, edgeSnapshots)
        graphFile(ctx).writeText(json.encodeToString(snapshot))
        persistOplog(ctx)
    }

    fun pendingOpsSnapshot(): List<GraphOp> = pendingOps.toList()

    fun lastSyncedClockValue(): Long = lastSyncedClock

    fun markOpsSynced(upToClock: Long) {
        lastSyncedClock = maxOf(lastSyncedClock, upToClock)
        pendingOps.removeAll { it.logicalClock <= upToClock }
        persistOplog(appContext ?: return)
    }

    internal fun applyRemoteOpWithoutRecording(op: GraphOp) {
        if (op.anchorId == root.id && op.kind != "connect") {
            return
        }
        val localClock = anchorClocks[op.anchorId] ?: 0L
        when (op.kind) {
            "delete" -> {
                if (op.logicalClock >= localClock) {
                    nodes.remove(op.anchorId)
                    outEdges.values.forEach { list -> list.remove(op.anchorId) }
                    outEdges.remove(op.anchorId)
                    tombstones.add(op.anchorId)
                    anchorClocks[op.anchorId] = op.logicalClock
                }
            }
            "spawn" -> {
                if (op.logicalClock >= localClock && op.anchorId !in tombstones) {
                    val node = json.decodeFromJsonElement<Node>(op.payload)
                    nodes[node.id] = node
                    tombstones.remove(node.id)
                    anchorClocks[op.anchorId] = op.logicalClock
                }
            }
            "connect" -> {
                val from = op.payload["from"]?.jsonPrimitive?.content ?: return
                val to = op.payload["to"]?.jsonPrimitive?.content ?: return
                if (op.logicalClock >= (anchorClocks[from] ?: 0L)) {
                    outEdges.getOrPut(from) { mutableListOf() }.add(to)
                    anchorClocks[from] = maxOf(anchorClocks[from] ?: 0L, op.logicalClock)
                }
            }
        }
    }

    private fun recordOp(anchorId: String, kind: String, payload: JsonObject) {
        logicalClock += 1
        anchorClocks[anchorId] = logicalClock
        pendingOps.add(
            GraphOp(
                opId = UUID.randomUUID().toString(),
                anchorId = anchorId,
                kind = kind,
                payload = payload,
                logicalClock = logicalClock,
            )
        )
        persistOplog(appContext ?: return)
    }

    private fun load() {
        val ctx = appContext ?: return
        loadGraph(ctx)
        loadOplog(ctx)
    }

    private fun loadGraph(ctx: Context) {
        val file = graphFile(ctx)
        if (!file.exists()) {
            return
        }
        val snapshot = json.decodeFromString<GraphSnapshot>(file.readText())
        nodes.clear()
        outEdges.clear()
        nodes[root.id] = root
        for (nodeJson in snapshot.nodes) {
            val node = json.decodeFromJsonElement<Node>(nodeJson)
            nodes[node.id] = node
        }
        for (edge in snapshot.edges) {
            outEdges.getOrPut(edge.from) { mutableListOf() }.add(edge.to)
        }
    }

    private fun loadOplog(ctx: Context) {
        val file = oplogFile(ctx)
        if (!file.exists()) {
            return
        }
        val snapshot = json.decodeFromString<OplogSnapshot>(file.readText())
        logicalClock = snapshot.logicalClock
        lastSyncedClock = snapshot.lastSyncedClock
        pendingOps.clear()
        pendingOps.addAll(snapshot.pendingOps)
        anchorClocks.clear()
        anchorClocks.putAll(snapshot.anchorClocks)
        tombstones.clear()
        tombstones.addAll(snapshot.tombstones)
    }

    private fun persistOplog(ctx: Context) {
        val snapshot = OplogSnapshot(
            logicalClock = logicalClock,
            lastSyncedClock = lastSyncedClock,
            pendingOps = pendingOps.toList(),
            anchorClocks = anchorClocks.toMap(),
            tombstones = tombstones.toSet(),
        )
        oplogFile(ctx).writeText(json.encodeToString(snapshot))
    }

    private fun graphFile(ctx: Context): File = File(ctx.filesDir, "jac_graph.json")

    private fun oplogFile(ctx: Context): File = File(ctx.filesDir, "jac_oplog.json")
}
