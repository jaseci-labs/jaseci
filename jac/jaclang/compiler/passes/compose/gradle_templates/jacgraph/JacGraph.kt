package {{package}}

import android.content.Context
import java.io.File
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.encodeToJsonElement

/**
 * In-memory graph store for on-device walker execution.
 *
 * Persistence (Phase 3): a single JSON snapshot in app-internal storage
 * ([Context.filesDir]/jac_graph.json). No schema migrations — trade simplicity over
 * Room/SQLite until dataset size forces a richer store.
 */
@Serializable
data class EdgeSnapshot(val from: String, val to: String)

@Serializable
data class GraphSnapshot(
    val nodes: List<JsonObject> = emptyList(),
    val edges: List<EdgeSnapshot> = emptyList(),
)

object JacGraph {
    private val nodes = mutableMapOf<String, Node>()
    private val outEdges = mutableMapOf<String, MutableList<String>>()
    private var appContext: Context? = null

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
        return node
    }

    fun connect(from: Node, to: Node) {
        outEdges.getOrPut(from.id) { mutableListOf() }.add(to.id)
    }

    fun neighbors(from: Node, dir: Dir, type: String? = null): List<Node> {
        if (dir != Dir.OUT) {
            throw UnsupportedOperationException("JacGraph.neighbors: only Dir.OUT is supported")
        }
        val ids = outEdges[from.id] ?: emptyList()
        return ids.mapNotNull { nodes[it] }.filter { type == null || it.type == type }
    }

    fun delete(node: Node) {
        nodes.remove(node.id)
        outEdges.values.forEach { list -> list.remove(node.id) }
        outEdges.remove(node.id)
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
    }

    private fun load() {
        val ctx = appContext ?: return
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

    private fun graphFile(ctx: Context): File = File(ctx.filesDir, "jac_graph.json")
}
