package {{package}}

import java.util.UUID
import kotlinx.serialization.Serializable

@Serializable
abstract class Node {
    abstract val id: String
    abstract val type: String
}

@Serializable
class RootNode(
    override val id: String = "root",
    override val type: String = "Root",
) : Node()

enum class Dir { OUT, IN, ANY }
