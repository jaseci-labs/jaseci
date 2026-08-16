package {{package}}

import kotlin.reflect.KClass
import kotlinx.serialization.KSerializer
import kotlinx.serialization.modules.PolymorphicModuleBuilder
import kotlinx.serialization.modules.SerializersModule
import kotlinx.serialization.modules.polymorphic
import kotlinx.serialization.modules.subclass

/**
 * kotlinx.serialization module for [Node] polymorphism. [RootNode] is always registered;
 * SvNodes.kt registers project node classes via [registerNodeSubclass] before
 * [JacGraph] first touches JSON. Registrations are stored as lambdas so each
 * class/serializer pair keeps its exact type through [subclass].
 */
object JacGraphSerializers {
    private val registrations =
        mutableListOf<PolymorphicModuleBuilder<Node>.() -> Unit>()

    fun <T : Node> registerNodeSubclass(klass: KClass<T>, serializer: KSerializer<T>) {
        registrations.add { subclass(klass, serializer) }
    }

    fun buildModule(): SerializersModule = SerializersModule {
        polymorphic(Node::class) {
            subclass(RootNode::class)
            registrations.forEach { it(this) }
        }
    }
}
